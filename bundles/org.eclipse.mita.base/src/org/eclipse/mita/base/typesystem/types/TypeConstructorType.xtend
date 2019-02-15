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
import org.eclipse.xtext.diagnostics.Severity

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.zip

@Accessors
class TypeConstructorType extends AbstractType {
	protected static Integer instanceCount = 0;
	protected val List<AbstractType> typeArguments;
	private transient val List<TypeVariable> _freeVars;
	
	static def unify(ConstraintSystem system, Iterable<AbstractType> instances) {
		// if not all sum types have the same number of arguments, return a new TV
		if(instances.map[it as TypeConstructorType].map[it.typeArguments.size].groupBy[it].size > 1) {
			return system.newTypeVariable(null);
		}
		// else transpose the instances' type args (so we have a list of all the first args, all the second args, etc.), then unify each of those
		return new TypeConstructorType(null, 
			BaseUtils.transpose(instances.map[it as TypeConstructorType].map[it.typeArguments])
				.map[TypeClassUnifier.INSTANCE.unifyTypeClassInstancesStructure(system, it)]
				.force
		)
	}
	
//	def getType() {
//		return typeArguments.head;
//	}
	
	new(EObject origin, Iterable<AbstractType> typeArguments) {
		super(origin, typeArguments.head.name);
		this.typeArguments = typeArguments.force;
		if(this.typeArguments.contains(null)) {
			throw new NullPointerException;
		}
		this._freeVars = typeArguments.flatMap[it.freeVars].force;
	}
	
	new(EObject origin, AbstractType type, List<AbstractType> typeArguments) {
		this(origin,  #[type] + typeArguments);
	}
	
	new(EObject origin, AbstractType type, Iterable<AbstractType> typeArguments) {
		this(origin, #[type] + typeArguments);
	}
		
	override Tree<AbstractType> quote() {
		val result = new Tree<AbstractType>(this);
		result.children += typeArguments.map[it.quote()];
		return result;
	}
	
	override quoteLike(Tree<AbstractType> structure) {
		val result = new Tree<AbstractType>(this);
		result.children += typeArguments.zip(structure.children).map[it.key.quoteLike(it.value)]
		return result;
	}
	
	def AbstractTypeConstraint getVariance(ValidationIssue issue, int typeArgumentIdx, AbstractType tau, AbstractType sigma) {
		if(typeArgumentIdx > 0) {
			return getVarianceForArgs(issue, typeArgumentIdx, tau, sigma);
		}
		return new EqualityConstraint(tau, sigma, new ValidationIssue(issue, '''Incompatible types: %1$s is not %2$s.'''));
	}
	protected def AbstractTypeConstraint getVarianceForArgs(ValidationIssue issue, int typeArgumentIdx, AbstractType tau, AbstractType sigma) {
		return new EqualityConstraint(tau, sigma, new ValidationIssue(issue, '''Incompatible types: %1$s is not %2$s.'''));
	}
	
	def void expand(ConstraintSystem system, Substitution s, TypeVariable tv) {
		val newTypeVars = typeArguments.map[ system.newTypeVariable(it.origin) as AbstractType ].force;
		val newCType = new TypeConstructorType(origin, newTypeVars);
		s.add(tv, newCType);
	}
		
	override toString() {
		return '''«super.toString»«IF !typeArguments.tail.empty»<«typeArguments.tail.join(", ")»>«ENDIF»'''
	}
	
	override getFreeVars() {
		return _freeVars;
	}
	
	override toGraphviz() {
		'''«FOR t: typeArguments»"«t»" -> "«this»"; "«this»" -> "«t»" «t.toGraphviz»«ENDFOR»''';
	}
		
	override map((AbstractType)=>AbstractType f) {
		val newTypeArgs = typeArguments.map[ it.map(f) ].force;
		if(typeArguments.zip(newTypeArgs).exists[it.key !== it.value]) {
			return new TypeConstructorType(origin, newTypeArgs);
		}
		return this;
	}
	
	override unquote(Iterable<Tree<AbstractType>> children) {
		return new TypeConstructorType(origin, children.map[it.node.unquote(it.children)].force);
	}
	
	override boolean equals(Object obj) {
		if(this === obj) { 
			return true	
		}
		if(obj === null) {
			return false
		}
		if(getClass() !== obj.getClass()) {
			return false
		}
		if(!super.equals(obj)) {
			return false
		}
		var TypeConstructorType other = (obj as TypeConstructorType)
		if (this.typeArguments === null) {
			if(other.typeArguments !== null) {
				return false
			}
		} else if(this.typeArguments.size != (other.typeArguments.size)) {
			return false
		}
		else if(this.typeArguments.zip(other.typeArguments).exists[!it.key.equals(it.value)]) {
			return false;
		}
		return true
	}

	@Pure override int hashCode() {
		val int prime = 31
		var int result = super.hashCode()
		result = prime * result + (if((this.typeArguments === null)) 0 else this.typeArguments.hashCode() )
		return result
	}
}