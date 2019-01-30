package org.eclipse.mita.base.typesystem.infra

import com.google.inject.Inject
import java.util.HashSet
import java.util.List
import java.util.Set
import org.eclipse.core.runtime.CoreException
import org.eclipse.core.runtime.IStatus
import org.eclipse.core.runtime.Status
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.BaseKind
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.FloatingType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.Signedness
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeHole
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.diagnostics.Severity

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.zip
import org.eclipse.mita.base.typesystem.solver.MostGenericUnifierComputer

class SubtypeChecker {
	
	@Inject extension
	StdlibTypeRegistry typeRegistry;
	
	@Inject
	MostGenericUnifierComputer mguComputer;
	
	public static dispatch def getSuperTypeGraphHandle(AbstractType t) {
		return t;
	}
	public static dispatch def getSuperTypeGraphHandle(TypeConstructorType t) {
		return t.type;
	}
	
	public static def isExplicitSubtypeOf(Graph<AbstractType> explicitRelations, AbstractType sub, AbstractType top) {
		return explicitRelations.reverseMap.get(sub)
			.flatMap[explicitRelations.outgoing.get(it)]
			.map[explicitRelations.nodeIndex.get(it)]
			.exists[it == top]
	}
	
	def Set<AbstractType> getSuperTypes(ConstraintSystem s, AbstractType t, EObject typeResolveOrigin) {
		val g = s.explicitSubtypeRelations;
		val idxs = g.reverseMap.get(t.superTypeGraphHandle) ?: #[];
		val explicitSuperTypes = #[t] + idxs.flatMap[
			val keys = g.walk(g.outgoing, new HashSet(), it) [i, v | i -> v];
			return keys.map[key_typeName | 
				val realType = s.explicitSubtypeRelationsTypeSource.get(key_typeName.key) ?: key_typeName.value
				if(realType.name != key_typeName.value.name) {
					throw new CoreException(new Status(IStatus.ERROR, "org.eclipse.mita.base", "Bad reverse lookup!"));
				}
				return realType;
			];
		].force;
		val ta_t = s.getOptionalType(typeResolveOrigin ?: t.origin).instantiate(s);
		val ta = ta_t.key.head;
		val optionalType = ta_t.value
		return explicitSuperTypes.flatMap[s.doGetSuperTypes(it, typeResolveOrigin ?: it.origin)].flatMap[#[it, optionalType.replace(ta, it)]].toSet;
	}
	
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, IntegerType t, EObject typeResolveOrigin) {
		return getIntegerTypes(typeResolveOrigin).filter[isSubType(s, typeResolveOrigin, t, it)].force
	}
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, TypeConstructorType t, EObject typeResolveOrigin) {
		return  #[t];
	}
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, AbstractType t, EObject typeResolveOrigin) {
		return #[t];
	}
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, FloatingType t, EObject typeResolveOrigin) {
		return getFloatingTypes(typeResolveOrigin).filter[isSubType(s, typeResolveOrigin, t, it)].force
	}
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, Object t, EObject typeResolveOrigin) {
		return #[];
	}
	dispatch def Iterable<AbstractType> doGetSuperTypes(ConstraintSystem s, Void v, EObject typeResolveOrigin) {
		return #[]
	}
	dispatch def Iterable<AbstractType> getSubTypes(ConstraintSystem s, IntegerType t, EObject typeResolveOrigin) {
		return getIntegerTypes(typeResolveOrigin).filter[isSubType(s, typeResolveOrigin, it, t)].force
	}
	dispatch def Iterable<AbstractType> getSubTypes(ConstraintSystem s, FloatingType t, EObject typeResolveOrigin) {
		return getFloatingTypes(typeResolveOrigin).filter[isSubType(s, typeResolveOrigin, it, t)].force
	}
	dispatch def Iterable<AbstractType> getSubTypes(ConstraintSystem s, SumType t, EObject typeResolveOrigin) {
		return #[t] + t.typeArguments.flatMap[getSubTypes(s, it, typeResolveOrigin)].force;
	}
	dispatch def Iterable<AbstractType> getSubTypes(ConstraintSystem s, TypeConstructorType t, EObject typeResolveOrigin) {
		return (#[t, new BottomType(null, "")] + if(t.name == "optional") {
			getSubTypes(s, t.typeArguments.head, typeResolveOrigin);
		} else {
			#[];
		}).force;
	}
	dispatch def Iterable<AbstractType> getSubTypes(ConstraintSystem s, AbstractType t, EObject typeResolveOrigin) {
		return #[t, new BottomType(null, "")];
	}
	dispatch def getSubTypes(ConstraintSystem s, Object t, EObject typeResolveOrigin) {
		return #[];
	}
	
	def boolean isSubType(ConstraintSystem s, EObject context, AbstractType sub, AbstractType top) {
		return isSubtypeOf(s, context, sub, top).valid;
	}
	
	protected def SubtypeCheckResult checkByteWidth(IntegerType sub, IntegerType top, int bSub, int bTop) {
		return (bSub <= bTop).subtypeMsgFromBoolean('''«top.name» is too small for «sub.name»''');
	}
	
	dispatch def SubtypeCheckResult isSubtypeOf(ConstraintSystem s, EObject context, FloatingType sub, FloatingType top) {
		return (sub.widthInBytes <= top.widthInBytes).subtypeMsgFromBoolean(sub, top);
	}
	dispatch def SubtypeCheckResult isSubtypeOf(ConstraintSystem s, EObject context, IntegerType sub, IntegerType top) {		
		val bTop = top.widthInBytes;
		val int bSub = switch(sub.signedness) {
			case Signed: {
				if(top.signedness != Signedness.Signed) {
					return SubtypeCheckResult.invalid('''Incompatible signedness between «top.name» and «sub.name»''');
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
	
	dispatch def SubtypeCheckResult isSubtypeOf(ConstraintSystem s, EObject context, FunctionType sub, FunctionType top) {
		//    fa :: a -> b   <:   fb :: c -> d 
		// ⟺ every fa can be used as fb 
		// ⟺ b >: d ∧    a <: c
		return isSubtypeOf(s, context, top.from, sub.from).orElse(isSubtypeOf(s, context, sub.to, top.to));
	}
			
	dispatch def SubtypeCheckResult isSubtypeOf(ConstraintSystem s, EObject context, BottomType sub, AbstractType sup) {
		// ⊥ is subtype of everything
		return new SubtypeCheckResult(#[sub.message], #[]);
	}
	
	dispatch def SubtypeCheckResult isSubtypeOf(ConstraintSystem s, EObject context, SumType sub, SumType top) {
		top.typeArguments.forall[topAlt | sub.typeArguments.exists[subAlt | isSubType(s, context, subAlt, topAlt)]].subtypeMsgFromBoolean(sub, top)
	}
	
	dispatch def SubtypeCheckResult isSubtypeOf(ConstraintSystem s, EObject context, ProdType sub, SumType top) {
		val subat = sub.type;
		val topat = top.type;
		return (isExplicitSubtypeOf(s.explicitSubtypeRelations, subat, topat)).subtypeMsgFromBoolean(sub, top);
	}
	
	dispatch def SubtypeCheckResult isSubtypeOf(ConstraintSystem s, EObject context, ProdType sub, ProdType top) {
		if(sub.typeArguments.length != top.typeArguments.length) {
			return SubtypeCheckResult.invalid('''«sub» and «top» differ in the number of type arguments''')
		}
		val result = sub.typeArguments.zip(top.typeArguments).map[isSubtypeOf(s, context, it.key, it.value)].fold(SubtypeCheckResult.valid, [scr1, scr2 | scr1.orElse(scr2)])
		if(result.invalid) {
			return SubtypeCheckResult.invalid(#['''«sub.name» isn't structurally a subtype of «top.name»'''] + result.messages);
		}
		return result;
	}
	
	dispatch def SubtypeCheckResult isSubtypeOf(ConstraintSystem s, EObject context, BaseKind sub, BaseKind top) {
		return isSubtypeOf(s, context, sub.kindOf, top.kindOf);
	}
	dispatch def SubtypeCheckResult isSubtypeOf(ConstraintSystem s, EObject context, AbstractType sub, AbstractType top) {
		return (getSubTypes(s, top, context).toList.exists[mguComputer.compute(null, sub, it).valid]).subtypeMsgFromBoolean(sub, top);
	}
	
	dispatch def SubtypeCheckResult isSubtypeOf(ConstraintSystem s, EObject context, TypeHole sub, AbstractType top) {
		return new SubtypeCheckResult(#[], #[new SubtypeConstraint(sub, top, new ValidationIssue(Severity.ERROR, '''Couldn't infer type/arg here''', top.origin, null, ""))]);
	}
	dispatch def SubtypeCheckResult isSubtypeOf(ConstraintSystem s, EObject context, AbstractType sub, TypeHole top) {
		return new SubtypeCheckResult(#[], #[new SubtypeConstraint(sub, top, new ValidationIssue(Severity.ERROR, '''Couldn't infer type/arg here''', top.origin, null, ""))]);
	}
	
	protected def SubtypeCheckResult subtypeMsgFromBoolean(boolean isSuperType, AbstractType sub, AbstractType top) {
		val ln = BaseUtils.lineNumberOf(1);
		return isSuperType.subtypeMsgFromBoolean(sub, top, ln);
	}
	protected def SubtypeCheckResult subtypeMsgFromBoolean(boolean isSuperType, AbstractType sub, AbstractType top, int ln) {
		return isSuperType.subtypeMsgFromBoolean('''STR:«BaseUtils.lineNumber»->«ln»: «sub» is not a subtype of «top»''')
	}
	protected def SubtypeCheckResult subtypeMsgFromBoolean(boolean isSuperType, String msg) {
		if(!isSuperType) {
			return SubtypeCheckResult.invalid(msg);
		}
		return SubtypeCheckResult.valid;
	}
	
	
}

@Accessors
class SubtypeCheckResult {
	val List<AbstractTypeConstraint> constraints = newArrayList;
	val List<String> messages = newArrayList;
	
	new(Iterable<String> msgs, Iterable<AbstractTypeConstraint> tcs) {
		messages += msgs;
		constraints += tcs;
	}
	
	def boolean isValid() {
		return messages.empty;
	}
	def boolean isInvalid() {
		return !messages.empty;
	}
	
	static def SubtypeCheckResult valid() {
		return new SubtypeCheckResult(#[], #[]);
	}
	static def SubtypeCheckResult invalid(String msg) {
		return new SubtypeCheckResult(#[msg], #[]);
	}
	static def SubtypeCheckResult invalid(Iterable<String> msgs) {
		return new SubtypeCheckResult(msgs, #[]);
	}
	def SubtypeCheckResult orElse(SubtypeCheckResult other) {
		return new SubtypeCheckResult(messages + other.messages, constraints + other.constraints);	
	}
}