package org.eclipse.mita.base.typesystem

import com.google.common.base.Optional
import com.google.inject.Inject
import java.util.Set
import java.util.regex.Pattern
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.types.NativeType
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.BaseKind
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.FloatingType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.Signedness
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.scoping.IScopeProvider

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.zip
import org.eclipse.mita.base.util.BaseUtils

class StdlibTypeRegistry {
	public static val voidTypeQID = QualifiedName.create(#["stdlib", "void"]);
	public static val stringTypeQID = QualifiedName.create(#["stdlib", "string"]);
	public static val floatTypeQID = QualifiedName.create(#["stdlib", "float"]);
	public static val doubleTypeQID = QualifiedName.create(#["stdlib", "double"]);
	public static val integerTypeQIDs = #['xint8', 'int8', 'uint8', 'int16', 'xint16', 'uint16', 'xint32', 'int32', 'uint32'].map[QualifiedName.create(#["stdlib", it])];
	public static val optionalTypeQID = QualifiedName.create(#["stdlib", "optional"]);
	public static val sigInstTypeQID = QualifiedName.create(#["stdlib", "siginst"]);
	public static val modalityTypeQID = QualifiedName.create(#["stdlib", "modality"]);
	public static val arrayTypeQID = QualifiedName.create(#["stdlib", "array"]);
	public static val plusFunctionQID = QualifiedName.create(#["stdlib", "__PLUS__"]);
	public static val minusFunctionQID = QualifiedName.create(#["stdlib", "__MINUS__"]);
	
	@Inject IScopeProvider scopeProvider;
	
	protected boolean isLinking = false;
	
	public def setIsLinking(boolean isLinking) {
		this.isLinking = isLinking;
	}
	
	def getTypeModelObject(EObject context, QualifiedName qn) {
		if(isLinking) {
			return null;
		}
		val scope = scopeProvider.getScope(context, TypesPackage.eINSTANCE.presentTypeSpecifier_Type);
		val obj = scope.getSingleElement(qn)?.EObjectOrProxy;
		return obj;
	}
	def getTypeModelObjectProxy(ConstraintSystem system, EObject context, QualifiedName qn) {
		if(isLinking) {
			return system.getTypeVariableProxy(context, TypesPackage.eINSTANCE.presentTypeSpecifier_Type, qn);
		}
		return system.getTypeVariable(getTypeModelObject(context, qn));
	}
	
	def getModelObjects(ConstraintSystem system, EObject context, QualifiedName qn, EReference ref) {
		if(isLinking) {
			return #[system.getTypeVariableProxy(context, ref, qn)];
		}
		val scope = scopeProvider.getScope(context, ref);
		val obj = scope.getElements(qn).map[EObjectOrProxy].map[system.getTypeVariable(it)].force;
		return obj;
	}
			
	protected def getVoidType(EObject context) {
		val voidType = getTypeModelObject(context, StdlibTypeRegistry.voidTypeQID);
		return new AtomicType(voidType, "void");
	}
	
	protected def getStringType(EObject context) {
		val stringType = getTypeModelObject(context, StdlibTypeRegistry.stringTypeQID);
		return new AtomicType(stringType, "string");
	}
	
	protected def getFloatType(EObject context) {
		val floatType = getTypeModelObject(context, StdlibTypeRegistry.floatTypeQID);
		return translateNativeType(floatType as NativeType);
	}
	
	protected def getDoubleType(EObject context) {
		val doubleType = getTypeModelObject(context, StdlibTypeRegistry.doubleTypeQID);
		return translateNativeType(doubleType as NativeType);
	}
	
	protected def getOptionalType(ConstraintSystem system, EObject context) {
		val optionalType = getTypeModelObject(context, StdlibTypeRegistry.optionalTypeQID) as GeneratedType;
		val typeArgs = #[system.newTypeVariable(optionalType.typeParameters.head)]
		return new TypeScheme(optionalType, typeArgs, new TypeConstructorType(optionalType, "optional", typeArgs.map[it as AbstractType]));
	}
	
	protected def getSigInstType(ConstraintSystem system, EObject context) {
		val sigInstType = getTypeModelObject(context, StdlibTypeRegistry.sigInstTypeQID) as GeneratedType;
		val typeArgs = #[system.newTypeVariable(sigInstType.typeParameters.head)]
		return new TypeScheme(sigInstType, typeArgs, new TypeConstructorType(sigInstType, "siginst", typeArgs.map[it as AbstractType]));
	}

	protected def getModalityType(ConstraintSystem system, EObject context) {
		val modalityType = getTypeModelObject(context, StdlibTypeRegistry.modalityTypeQID) as GeneratedType;
		val typeArgs = #[system.newTypeVariable(modalityType.typeParameters.head)]
		return new TypeScheme(modalityType, typeArgs, new TypeConstructorType(modalityType, "modality", typeArgs.map[it as AbstractType]));
	}
		
	protected def Iterable<AbstractType> getFloatingTypes(EObject context) {
		return #[getFloatType(context), getDoubleType(context)];
	}
	/*protected*/ def Iterable<AbstractType> getIntegerTypes(EObject context) {
		val typesScope = scopeProvider.getScope(context, TypesPackage.eINSTANCE.presentTypeSpecifier_Type);
		return StdlibTypeRegistry.integerTypeQIDs
			.map[typesScope.getSingleElement(it).EObjectOrProxy]
			.filter(NativeType)
			.map[translateNativeType(it)].force
	}
	
	def AbstractType translateNativeType(NativeType type) {
		val intPatternMatcher = Pattern.compile("(xint|int|uint)(\\d+)$").matcher(type?.name ?: "");
		if(intPatternMatcher.matches) {
			val signed = intPatternMatcher.group(1) == 'int';
			val unsigned = intPatternMatcher.group(1) == 'uint';
			val size = Integer.parseInt(intPatternMatcher.group(2)) / 8;
			
			new IntegerType(type, size, if(signed) Signedness.Signed else if(unsigned) Signedness.Unsigned else Signedness.DontCare);
		} else if(type?.name == "float") {
			new FloatingType(type, 4);
		} else if(type?.name == "double") {
			new FloatingType(type, 8);
		} else {
			new AtomicType(type, type.name);
		}
	}
	
	def Set<AbstractType> getSuperTypes(ConstraintSystem s, AbstractType t) {
		return getSuperTypes(s, t, null);
	}
	def Set<AbstractType> getSuperTypes(ConstraintSystem s, AbstractType t, EObject typeResolveOrigin) {
		val idxs = s.explicitSubtypeRelations.reverseMap.get(t) ?: #[];
		val explicitSuperTypes = #[t] + idxs.flatMap[s.explicitSubtypeRelations.getSuccessors(it)];
		val ta_t = s.getOptionalType(typeResolveOrigin ?: t.origin).instantiate(s);
		val ta = ta_t.key.head;
		val optionalType = ta_t.value
		return explicitSuperTypes.flatMap[s.doGetSuperTypes(it, typeResolveOrigin ?: it.origin)].flatMap[#[it, optionalType.replace(ta, it)]].toSet;
	}
	
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, IntegerType t, EObject typeResolveOrigin) {
		return getIntegerTypes(typeResolveOrigin).filter[typeResolveOrigin.isSubType(t, it)].force
	}
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, TypeConstructorType t, EObject typeResolveOrigin) {
		return  #[t] + t.superTypes.flatMap[s.getSuperTypes(it, typeResolveOrigin)].force;
	}
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, AbstractType t, EObject typeResolveOrigin) {
		return #[t];
	}
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, FloatingType t, EObject typeResolveOrigin) {
		return getFloatingTypes(typeResolveOrigin).filter[typeResolveOrigin.isSubType(t, it)].force
	}
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, Object t, EObject typeResolveOrigin) {
		return #[];
	}
	dispatch def Iterable<AbstractType> getSubTypes(IntegerType t, EObject typeResolveOrigin) {
		return getIntegerTypes(typeResolveOrigin).filter[typeResolveOrigin.isSubType(it, t)].force
	}
	dispatch def Iterable<AbstractType> getSubTypes(FloatingType t, EObject typeResolveOrigin) {
		return getFloatingTypes(typeResolveOrigin).filter[typeResolveOrigin.isSubType(it, t)].force
	}
	dispatch def Iterable<AbstractType> getSubTypes(SumType t, EObject typeResolveOrigin) {
		return #[t] + t.typeArguments.flatMap[getSubTypes(it, typeResolveOrigin)].force;
	}
	dispatch def Iterable<AbstractType> getSubTypes(TypeConstructorType t, EObject typeResolveOrigin) {
		return (#[t, new BottomType(null, "")] + if(t.name == "optional") {
			getSubTypes(t.typeArguments.head, typeResolveOrigin);
		} else {
			#[];
		}).force;
	}
	dispatch def Iterable<AbstractType> getSubTypes(AbstractType t, EObject typeResolveOrigin) {
		return #[t, new BottomType(null, "")];
	}
	dispatch def getSubTypes(Object t, EObject typeResolveOrigin) {
		return #[];
	}
	
	public def boolean isSubType(EObject context, AbstractType sub, AbstractType top) {
		return !context.isSubtypeOf(sub, top).present;
	}
	
	protected def Optional<String> checkByteWidth(IntegerType sub, IntegerType top, int bSub, int bTop) {
		return (bSub <= bTop).subtypeMsgFromBoolean('''STR:«BaseUtils.lineNumber»: «top.name» is too small for «sub.name»''');
	}
	
	public dispatch def Optional<String> isSubtypeOf(EObject context, FloatingType sub, FloatingType top) {
		return (sub.widthInBytes <= top.widthInBytes).subtypeMsgFromBoolean(sub, top);
	}
	public dispatch def Optional<String> isSubtypeOf(EObject context, IntegerType sub, IntegerType top) {		
		val bTop = top.widthInBytes;
		val int bSub = switch(sub.signedness) {
			case Signed: {
				if(top.signedness != Signedness.Signed) {
					return Optional.of('''STR:«BaseUtils.lineNumber»: Incompatible signedness between «top.name» and «sub.name»''');
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
	
	public dispatch def Optional<String> isSubtypeOf(EObject context, FunctionType sub, FunctionType top) {
		//    fa :: a -> b   <:   fb :: c -> d 
		// ⟺ every fa can be used as fb 
		// ⟺ b >: d ∧    a <: c
		return context.isSubtypeOf(top.from, sub.from).or(context.isSubtypeOf(sub.to, top.to));
	}
			
	public dispatch def Optional<String> isSubtypeOf(EObject context, BottomType sub, AbstractType sup) {
		// ⊥ is subtype of everything
		return Optional.absent;
	}
	
	public dispatch def Optional<String> isSubtypeOf(EObject context, SumType sub, SumType top) {
		top.typeArguments.forall[topAlt | sub.typeArguments.exists[subAlt | context.isSubType(subAlt, topAlt)]].subtypeMsgFromBoolean(sub, top)
	}
	
	public dispatch def Optional<String> isSubtypeOf(EObject context, ProdType sub, SumType top) {
		top.typeArguments.exists[context.isSubType(sub, it)].subtypeMsgFromBoolean(sub, top)
	}
	
	public dispatch def Optional<String> isSubtypeOf(EObject context, ProdType sub, ProdType top) {
		if(sub.typeArguments.length != top.typeArguments.length) {
			return Optional.of('''STR:«BaseUtils.lineNumber»: «sub.name» and «top.name» differ in the number of type arguments''')
		}
		val msg = sub.typeArguments.zip(top.typeArguments).map[context.isSubtypeOf(it.key, it.value).orNull].filterNull.join("\n")
		if(msg != "") {
			return Optional.of('''
			STR:«BaseUtils.lineNumber»: «sub.name» isn't structurally a subtype of «top.name»:
				«msg»''');
		}
		return Optional.absent;
	}
	public dispatch def Optional<String> isSubtypeOf(EObject context, AbstractType sub, BaseKind top) {
		return subtypeMsgFromBoolean(context.isSubType(sub, top.kindOf), sub, top);
	}
	public dispatch def Optional<String> isSubtypeOf(EObject context, BaseKind sub, BaseKind top) {
		return subtypeMsgFromBoolean(context.isSubType(sub.kindOf, top.kindOf), sub, top);
	}
	public dispatch def Optional<String> isSubtypeOf(EObject context, AbstractType sub, AbstractType top) {
		return (top.getSubTypes(context).toList.contains(sub)).subtypeMsgFromBoolean(sub, top);
	}
	
	protected def Optional<String> subtypeMsgFromBoolean(boolean isSuperType, AbstractType sub, AbstractType top) {
		val ln = BaseUtils.lineNumberOf(1);
		return isSuperType.subtypeMsgFromBoolean(sub, top, ln);
	}
	protected def Optional<String> subtypeMsgFromBoolean(boolean isSuperType, AbstractType sub, AbstractType top, int ln) {
		return isSuperType.subtypeMsgFromBoolean('''STR:«BaseUtils.lineNumber»->«ln»: «sub» is not a subtype of «top»''')
	}
	protected def Optional<String> subtypeMsgFromBoolean(boolean isSuperType, String msg) {
		if(!isSuperType) {
			return Optional.of(msg);
		}
		return Optional.absent;
	}
	
}
