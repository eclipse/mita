package org.eclipse.mita.base.typesystem

import com.google.common.base.Optional
import com.google.inject.Inject
import java.util.Set
import java.util.regex.Pattern
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.NativeType
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.Signedness
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.mita.base.typesystem.types.CoSumType

class StdlibTypeRegistry {
	public static val voidTypeQID = QualifiedName.create(#["stdlib", "void"]);
	public static val stringTypeQID = QualifiedName.create(#["stdlib", "string"]);
	public static val integerTypeQIDs = #['xint8', 'int8', 'uint8', 'int16', 'xint16', 'uint16', 'xint32', 'int32', 'uint32'].map[QualifiedName.create(#["stdlib", it])];
	
	@Inject IScopeProvider scopeProvider;
	
	public def getVoidType(EObject context) {
		val voidScope = scopeProvider.getScope(context, TypesPackage.eINSTANCE.presentTypeSpecifier_Type);
		val voidType = voidScope.getSingleElement(StdlibTypeRegistry.voidTypeQID).EObjectOrProxy;
		return new AtomicType(voidType, "void");
	}
	
	def getStringType(EObject context) {
		val stringScope = scopeProvider.getScope(context, TypesPackage.eINSTANCE.presentTypeSpecifier_Type);
		val stringType = stringScope.getSingleElement(StdlibTypeRegistry.stringTypeQID).EObjectOrProxy;
		return new AtomicType(stringType, "string");
	}
	
	public def Iterable<AbstractType> getIntegerTypes(EObject context) {
		val typesScope = scopeProvider.getScope(context, TypesPackage.eINSTANCE.presentTypeSpecifier_Type);
		return StdlibTypeRegistry.integerTypeQIDs
			.map[typesScope.getSingleElement(it).EObjectOrProxy]
			.filter(NativeType)
			.map[translateNativeType(it)]
	}
	
	public def AbstractType translateNativeType(NativeType type) {
		val intPatternMatcher = Pattern.compile("(xint|int|uint)(\\d+)$").matcher(type?.name ?: "");
		if(intPatternMatcher.matches) {
			val signed = intPatternMatcher.group(1) == 'int';
			val unsigned = intPatternMatcher.group(1) == 'uint';
			val size = Integer.parseInt(intPatternMatcher.group(2)) / 8;
			
			new IntegerType(type, size, if(signed) Signedness.Signed else if(unsigned) Signedness.Unsigned else Signedness.DontCare);
		} else {
			new AtomicType(type, type.name);
		}
	}
	
	def Set<AbstractType> getSuperTypes(ConstraintSystem s, Object t) {
		val idxs = s.explicitSubtypeRelations.reverseMap.get(t) ?: #[];
		val explicitSuperTypes = #[t] + idxs.flatMap[s.explicitSubtypeRelations.getSuccessors(it)];
		return explicitSuperTypes.flatMap[s.doGetSuperTypes(it)].toSet;
	}
	
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, IntegerType t) {
		return getIntegerTypes(t.origin).filter[t.isSubType(it)]
	}
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, TypeConstructorType t) {
		return t.superTypes.flatMap[s.getSuperTypes(it)] + #[t];
	}
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, AbstractType t) {
		return #[t];
	}
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, CoSumType t) {
		return #[t] + t.types.flatMap[s.getSuperTypes(it)];
	}
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, Object t) {
		return #[];
	}
	dispatch def Iterable<AbstractType> getSubTypes(IntegerType t) {
		return getIntegerTypes(t.origin).filter[it.isSubType(t)]
	}
	dispatch def Iterable<AbstractType> getSubTypes(SumType t) {
		return t.types.flatMap[getSubTypes] + #[t];
	}
	dispatch def Iterable<AbstractType> getSubTypes(AbstractType t) {
		return #[t, new BottomType(null, "")];
	}
	dispatch def getSubTypes(Object t) {
		return #[];
	}
	
	public def boolean isSubType(AbstractType sub, AbstractType top) {
		return !isSubtypeOf(sub, top).present;
	}
	
	protected def Optional<String> checkByteWidth(IntegerType sub, IntegerType top, int bSub, int bTop) {
		return (bSub <= bTop).subtypeMsgFromBoolean('''STR: «top.name» is too small for «sub.name»''');
	}
	
	public dispatch def Optional<String> isSubtypeOf(IntegerType sub, IntegerType top) {		
		val bTop = top.widthInBytes;
		val int bSub = switch(sub.signedness) {
			case Signed: {
				if(top.signedness != Signedness.Signed) {
					return Optional.of('''STR: Incompatible signedness between «top.name» and «sub.name»''');
				}
				sub.widthInBytes;
			}
			case Unsigned: {
				if(top.signedness != Signedness.Unsigned) {
					sub.widthInBytes + 1;
				}
				else {
					sub.widthInBytes;	
				}
			}
			case DontCare: {
				sub.widthInBytes;
			}
		}
		
		return checkByteWidth(sub, top, bSub, bTop);
	}
	
	public dispatch def Optional<String> isSubtypeOf(FunctionType sub, FunctionType top) {
		//    fa :: a -> b   <:   fb :: c -> d 
		// ⟺ every fa can be used as fb 
		// ⟺ b >: d ∧    a <: c
		return top.from.isSubtypeOf(sub.from).or(sub.to.isSubtypeOf(top.to));
	}
			
	public dispatch def Optional<String> isSubtypeOf(BottomType sub, AbstractType sup) {
		// ⊥ is subtype of everything
		return Optional.absent;
	}
	
	public dispatch def Optional<String> isSubtypeOf(SumType sub, SumType top) {
		top.types.forall[topAlt | sub.types.exists[subAlt | subAlt.isSubType(topAlt)]].subtypeMsgFromBoolean(sub, top)
	}
	
	public dispatch def Optional<String> isSubtypeOf(ProdType sub, SumType top) {
		top.types.exists[sub.isSubType(it)].subtypeMsgFromBoolean(sub, top)
	}
	
	public dispatch def Optional<String> isSubtypeOf(ProdType sub, ProdType top) {
		
	}
		
	public dispatch def Optional<String> isSubtypeOf(AbstractType sub, AbstractType top) {
		return (sub == top).subtypeMsgFromBoolean(sub, top);
	}
	
	protected def Optional<String> subtypeMsgFromBoolean(boolean isSuperType, AbstractType sub, AbstractType top) {
		return isSuperType.subtypeMsgFromBoolean('''STR: «sub.name» is not a subtype of «top.name»''')
	}
	protected def Optional<String> subtypeMsgFromBoolean(boolean isSuperType, String msg) {
		if(!isSuperType) {
			return Optional.of(msg);
		}
		return Optional.absent;
	}
	
}
