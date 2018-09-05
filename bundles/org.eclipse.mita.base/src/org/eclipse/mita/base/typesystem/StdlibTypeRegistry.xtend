package org.eclipse.mita.base.typesystem

import com.google.common.base.Optional
import com.google.inject.Inject
import java.util.Set
import java.util.regex.Pattern
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.types.NativeType
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.CoSumType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.Signedness
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.scoping.IScopeProvider

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.zip

class StdlibTypeRegistry {
	public static val voidTypeQID = QualifiedName.create(#["stdlib", "void"]);
	public static val stringTypeQID = QualifiedName.create(#["stdlib", "string"]);
	public static val integerTypeQIDs = #['xint8', 'int8', 'uint8', 'int16', 'xint16', 'uint16', 'xint32', 'int32', 'uint32'].map[QualifiedName.create(#["stdlib", it])];
	public static val arithmeticFunctionQIDs = #['__plus__', '__minus__', '__times__', '__division__', '__modulo__'].map[QualifiedName.create(#["stdlib", it])];
	public static val optionalTypeQID = QualifiedName.create(#["stdlib", "optional"]);
	public static val sigInstTypeQID = QualifiedName.create(#["stdlib", "siginst"]);
	public static val modalityTypeQID = QualifiedName.create(#["stdlib", "modality"]);
	
	@Inject IScopeProvider scopeProvider;
	
	def getTypeModelObject(EObject context, QualifiedName qn) {
		val scope = scopeProvider.getScope(context, TypesPackage.eINSTANCE.presentTypeSpecifier_Type);
		val obj = scope.getSingleElement(qn).EObjectOrProxy;
		return obj;
	}
		
	def getVoidType(EObject context) {
		val voidType = getTypeModelObject(context, StdlibTypeRegistry.voidTypeQID);
		return new AtomicType(voidType, "void");
	}
	
	def getStringType(EObject context) {
		val stringType = getTypeModelObject(context, StdlibTypeRegistry.stringTypeQID);
		return new AtomicType(stringType, "string");
	}
	
	def getOptionalType(EObject context) {
		val optionalType = getTypeModelObject(context, StdlibTypeRegistry.optionalTypeQID) as GeneratedType;
		val typeArgs = #[new TypeVariable(optionalType.typeParameters.head)]
		return new TypeScheme(optionalType, typeArgs, new TypeConstructorType(optionalType, "optional", typeArgs.map[it as AbstractType]));
	}
	
	def getSigInstType(EObject context) {
		val sigInstType = getTypeModelObject(context, StdlibTypeRegistry.sigInstTypeQID) as GeneratedType;
		val typeArgs = #[new TypeVariable(sigInstType.typeParameters.head)]
		return new TypeScheme(sigInstType, typeArgs, new TypeConstructorType(sigInstType, "siginst", typeArgs.map[it as AbstractType]));
	}

	def getModalityType(EObject context) {
		val modalityType = getTypeModelObject(context, StdlibTypeRegistry.modalityTypeQID) as GeneratedType;
		val typeArgs = #[new TypeVariable(modalityType.typeParameters.head)]
		return new TypeScheme(modalityType, typeArgs, new TypeConstructorType(modalityType, "modality", typeArgs.map[it as AbstractType]));
	}
	
	def getArithmeticFunctions(EObject context, String name) {
		val scope = scopeProvider.getScope(context, ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference);
		return arithmeticFunctionQIDs.filter[it.lastSegment.contains(name)].flatMap[scope.getElements(it)].map[EObjectOrProxy]
	}
	
	public def Iterable<AbstractType> getIntegerTypes(EObject context) {
		val typesScope = scopeProvider.getScope(context, TypesPackage.eINSTANCE.presentTypeSpecifier_Type);
		return StdlibTypeRegistry.integerTypeQIDs
			.map[typesScope.getSingleElement(it).EObjectOrProxy]
			.filter(NativeType)
			.map[translateNativeType(it)].force
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
	
	def Set<AbstractType> getSuperTypes(ConstraintSystem s, AbstractType t) {
		val idxs = s.explicitSubtypeRelations.reverseMap.get(t) ?: #[];
		val explicitSuperTypes = #[t] + idxs.flatMap[s.explicitSubtypeRelations.getSuccessors(it)];
		val ta_t = getOptionalType(t.origin).instantiate();
		val ta = ta_t.key.head;
		val optionalType = ta_t.value
		return explicitSuperTypes.flatMap[s.doGetSuperTypes(it)].flatMap[#[it, optionalType.replace(ta, it)]].toSet;
	}
	
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, IntegerType t) {
		return getIntegerTypes(t.origin).filter[t.isSubType(it)].force
	}
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, TypeConstructorType t) {
		return  #[t] + t.superTypes.flatMap[s.getSuperTypes(it)].force;
	}
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, AbstractType t) {
		return #[t];
	}
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, CoSumType t) {
		return #[t] + t.typeArguments.flatMap[s.getSuperTypes(it)].force;
	}
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, Object t) {
		return #[];
	}
	dispatch def Iterable<AbstractType> getSubTypes(IntegerType t) {
		return getIntegerTypes(t.origin).filter[it.isSubType(t)].force
	}
	dispatch def Iterable<AbstractType> getSubTypes(SumType t) {
		return #[t] + t.typeArguments.flatMap[getSubTypes].force;
	}
	dispatch def Iterable<AbstractType> getSubTypes(TypeConstructorType t) {
		return (#[t, new BottomType(null, "")] + if(t.name == "optional") {
			t.typeArguments.head.subTypes;
		} else {
			#[];
		}).force;
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
		top.typeArguments.forall[topAlt | sub.typeArguments.exists[subAlt | subAlt.isSubType(topAlt)]].subtypeMsgFromBoolean(sub, top)
	}
	
	public dispatch def Optional<String> isSubtypeOf(ProdType sub, SumType top) {
		top.typeArguments.exists[sub.isSubType(it)].subtypeMsgFromBoolean(sub, top)
	}
	
	public dispatch def Optional<String> isSubtypeOf(ProdType sub, ProdType top) {
		if(sub.typeArguments.length != top.typeArguments.length) {
			return Optional.of('''STR: «sub.name» and «top.name» differ in the number of type arguments''')
		}
		val msg = sub.typeArguments.zip(top.typeArguments).map[it.key.isSubtypeOf(it.value).orNull].filterNull.join("\n")
		if(msg != "") {
			return Optional.of('''
			STR: «sub.name» isn't structurally a subtype of «top.name»:
				«msg»''');
		}
		return Optional.absent;
	}
		
	public dispatch def Optional<String> isSubtypeOf(AbstractType sub, AbstractType top) {
		return (top.subTypes.toList.contains(sub)).subtypeMsgFromBoolean(sub, top);
	}
	
	protected def Optional<String> subtypeMsgFromBoolean(boolean isSuperType, AbstractType sub, AbstractType top) {
		return isSuperType.subtypeMsgFromBoolean('''STR: «sub» is not a subtype of «top»''')
	}
	protected def Optional<String> subtypeMsgFromBoolean(boolean isSuperType, String msg) {
		if(!isSuperType) {
			return Optional.of(msg);
		}
		return Optional.absent;
	}
	
}
