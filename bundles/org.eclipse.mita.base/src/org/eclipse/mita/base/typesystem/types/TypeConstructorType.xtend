package org.eclipse.mita.base.typesystem.types

import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.infra.Tree
import org.eclipse.mita.base.typesystem.infra.TypeClassUnifier
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtext.diagnostics.Severity

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.zip

@EqualsHashCode
@Accessors
class TypeConstructorType extends AbstractType {
	protected static Integer instanceCount = 0;
	protected val AbstractType type;
	protected val List<AbstractType> typeArguments;
	
	static def unify(ConstraintSystem system, Iterable<AbstractType> instances) {
		// if not all sum types have the same number of arguments, return a new TV
		if(instances.map[it as TypeConstructorType].map[it.typeArguments.size].groupBy[it].size > 1) {
			return system.newTypeVariable(null);
		}
		// else transpose the instances' type args (so we have a list of all the first args, all the second args, etc.), then unify each of those
		return new TypeConstructorType(null, TypeClassUnifier.INSTANCE.unifyTypeClassInstancesStructure(system, instances.map[it as TypeConstructorType].map[it.type]),
			BaseUtils.transpose(instances.map[it as TypeConstructorType].map[it.typeArguments])
				.map[TypeClassUnifier.INSTANCE.unifyTypeClassInstancesStructure(system, it)]
				.force
		)
	}
	
	new(EObject origin, AbstractType type, List<AbstractType> typeArguments) {
		super(origin, type.name);
		this.type = type;
		this.typeArguments = typeArguments;
	}
	
	new(EObject origin, AbstractType type, Iterable<AbstractType> typeArguments) {
		super(origin, type.name);
		this.type = type;
		this.typeArguments = typeArguments.force;
	}
		
	override Tree<AbstractType> quote() {
		val result = new Tree<AbstractType>(this);
		result.children += type.quote();
		result.children += typeArguments.map[it.quote()];
		return result;
	}
	
	override quoteLike(Tree<AbstractType> structure) {
		val result = new Tree<AbstractType>(this);
		result.children += (#[type] + typeArguments).zip(structure.children).map[it.key.quoteLike(it.value)]
		return result;
	}
	
	def AbstractTypeConstraint getVariance(int typeArgumentIdx, AbstractType tau, AbstractType sigma) {
		return new EqualityConstraint(tau, sigma, new ValidationIssue(Severity.ERROR, '''«tau» is not equal to «sigma»''', ""));
	}
	def void expand(ConstraintSystem system, Substitution s, TypeVariable tv) {
		val newTypeVars = typeArguments.map[ system.newTypeVariable(it.origin) as AbstractType ].force;
		val newCType = new TypeConstructorType(origin, type, newTypeVars);
		s.add(tv, newCType);
	}
		
	override toString() {
		return '''«super.toString»«IF !typeArguments.empty»<«typeArguments.join(", ")»>«ENDIF»'''
	}
	
	override getFreeVars() {
		return typeArguments.flatMap[it.freeVars];
	}
	
	override toGraphviz() {
		'''«FOR t: typeArguments»"«t»" -> "«this»"; "«this»" -> "«t»" «t.toGraphviz»«ENDFOR»''';
	}
		
	override map((AbstractType)=>AbstractType f) {
		val newTypeArgs = typeArguments.map[ it.map(f) ].force;
		val newType = type.map(f);
		if(type !== newType || typeArguments.zip(newTypeArgs).exists[it.key !== it.value]) {
			return new TypeConstructorType(origin, newType, newTypeArgs);
		}
		return this;
	}
	
	override unquote(Iterable<Tree<AbstractType>> children) {
		return new TypeConstructorType(origin, children.head.node.unquote(children.head.children), children.tail.map[it.node.unquote(it.children)].force);
	}
	
}