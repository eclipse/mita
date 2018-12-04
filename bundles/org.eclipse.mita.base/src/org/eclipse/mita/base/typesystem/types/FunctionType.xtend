package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.infra.TypeClassUnifier
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtext.diagnostics.Severity

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.zip

@EqualsHashCode
@Accessors
class FunctionType extends TypeConstructorType {
	static def unify(ConstraintSystem system, Iterable<AbstractType> instances) {
		return new FunctionType(null, instances.head.name, 
			TypeClassUnifier.INSTANCE.unifyTypeClassInstancesStructure(system, instances.map[it as FunctionType].map[it.from]),
			TypeClassUnifier.INSTANCE.unifyTypeClassInstancesStructure(system, instances.map[it as FunctionType].map[it.to])
		)
	}
			
	new(EObject origin, String cons, AbstractType from, AbstractType to) {
		this(origin, cons, #[from, to]);
		
//		if(from === null || to === null) {
//			throw new NullPointerException;
//		}
	}
	
	new(EObject origin, String cons, Iterable<AbstractType> typeArgs) {
		super(origin, cons, typeArgs);
	}
	
	def AbstractType getFrom() {
		return typeArguments.get(0);
	}
	def AbstractType getTo() {
		return typeArguments.get(1);
	}
	
	override toString() {
		from + " → " + to
	}
		
	override getFreeVars() {
		return #[from, to].filter(TypeVariable);
	}
	
	override getTypeArguments() {
		return #[from, to];
	}
	
	override getVariance(int typeArgumentIdx, AbstractType tau, AbstractType sigma) {
		if(typeArgumentIdx == 1) {
			return new SubtypeConstraint(tau, sigma, new ValidationIssue(Severity.ERROR, '''«tau» is not subtype of «sigma»''', ""));
		}
		else {
			// function arguments are contravariant
			return new SubtypeConstraint(sigma, tau, new ValidationIssue(Severity.ERROR, '''«sigma» is not subtype of «tau»''', ""));
		}
	}
	
	override expand(ConstraintSystem system, Substitution s, TypeVariable tv) {
		val newFType = new FunctionType(origin, name, system.newTypeVariable(from.origin), system.newTypeVariable(to.origin));
		s.add(tv, newFType);
	}
	
	override toGraphviz() {
		'''"«to»" -> "«this»"; "«this»" -> "«from»"; «to.toGraphviz» «from.toGraphviz»''';
	}
	


	
	override map((AbstractType)=>AbstractType f) {
		val newTypeArgs = typeArguments.map[ it.map(f) ].force;
		if(typeArguments.zip(newTypeArgs).exists[it.key !== it.value]) {
			return new FunctionType(origin, name, newTypeArgs);
		}
		return this;
	}
	
}