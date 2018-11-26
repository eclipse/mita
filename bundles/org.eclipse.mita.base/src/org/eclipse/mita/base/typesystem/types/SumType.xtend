package org.eclipse.mita.base.typesystem.types

import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtext.diagnostics.Severity

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.zip

@EqualsHashCode
@Accessors
class SumType extends TypeConstructorType {
	
	new(EObject origin, String name, List<AbstractType> typeArguments) {
		super(origin, name, typeArguments);
	}
	new(EObject origin, String name, Iterable<AbstractType> typeArguments) {
		super(origin, name, typeArguments);
	}
			
	override toString() {
		(name ?: "") + "(" + typeArguments.map[name].join(" | ") + ")"
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return new SumType(origin, name, this.typeArguments.map[ it.replace(from, with) ].force);
	}
			
	override getVariance(int typeArgumentIdx, AbstractType tau, AbstractType sigma) {
		return new SubtypeConstraint(tau, sigma, new ValidationIssue(Severity.ERROR, '''«tau» is not subtype of «sigma»''', ""));
	}
	
	override expand(ConstraintSystem system, Substitution s, TypeVariable tv) {
		val newTypeVars = typeArguments.map[ system.newTypeVariable(it.origin) as AbstractType ].force;
		val newSType = new SumType(origin, name, newTypeVars);
		s.add(tv, newSType);
	}
	override toGraphviz() {
		'''«FOR t: typeArguments»"«t»" -> "«this»"; «t.toGraphviz»«ENDFOR»''';
	}
		
	override map((AbstractType)=>AbstractType f) {
		val newTypeArgs = typeArguments.map[ it.map(f) ].force;
		if(typeArguments.zip(newTypeArgs).exists[it.key !== it.value]) {
			return new SumType(origin, name, newTypeArgs);	
		}
		return this;
	}
	
}