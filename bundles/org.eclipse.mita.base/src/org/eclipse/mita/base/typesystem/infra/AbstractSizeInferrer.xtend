package org.eclipse.mita.base.typesystem.infra

import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.typesystem.constraints.MaxConstraint
import org.eclipse.mita.base.typesystem.constraints.SumConstraint
import org.eclipse.mita.base.typesystem.solver.ConstraintSolution
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue

abstract class AbstractSizeInferrer {
	def ConstraintSolution createSizeConstraints(ConstraintSolution cs, Resource r);
	
	def ConstraintSolution validateSolution(ConstraintSolution cs, Resource r);
}

interface FunctionSizeInferrer {
	/**
	 * allows delegating calls to global implementation. 
	 * May only call delegate.infer on the passed EObject and its contained objects, not on references or containers.
	 * In fact, calling delegate.infer should be the default action of inferrers that are not some kind of "main" inferrer.
	 */
	def void setDelegate(TypeSizeInferrer delegate);
	/**
	 * Infers the size for EObject obj with type type. It does this by inserting constraints into c.system.
	 */
	def void createConstraints(InferenceContext c);
}

interface TypeSizeInferrer extends FunctionSizeInferrer {
	/**
	 * Unbinds size parameters in types of objects.
	 */
	def Pair<AbstractType, Iterable<EObject>> unbindSize(Resource r, ConstraintSystem system, EObject obj, AbstractType type);
		
	/**
	 * Finds the maximum size of all passed types.
	 */
	def void createConstraintsForMax(ConstraintSystem system, Resource r, MaxConstraint constraint);
	/**
	 * Finds the sum of all passed type sizes.
	 */
	def void createConstraintsForSum(ConstraintSystem system, Resource r, SumConstraint constraint);
	
	def boolean isFixedSize(TypeSpecifier ts);
	
	def AbstractType getZeroSizeType(InferenceContext c, AbstractType skeleton);
	
	/**
	 * wraps inner type by unwrapping obj.
	 * Example:
	 *   wrap((*a)[0], array<u8, 3>)
	 * = wrap((*a), array<array<u8, 3>, f1>)
	 * = wrap(a, &array<array<u8, 3>, f1>)
	 * 
	 * most size inferrers should implement this by calling delegate.wrap.
	 */
	def AbstractType wrap(InferenceContext c, EObject obj, AbstractType inner);
	
	def Iterable<ValidationIssue> validateSizeInference(Resource r, ConstraintSystem system, EObject origin, AbstractType type);
}

@FinalFieldsConstructor
@Accessors
@EqualsHashCode
class InferenceContext {
	val ConstraintSystem system;
	val Resource r;
	val EObject obj;
	val TypeVariable tv;
	val AbstractType type;
	
	new(InferenceContext self, AbstractType type) {
		this(self, self.obj, type);
	}
	
	new(InferenceContext self, EObject obj) {
		this(self, obj, self.type);
	}
	
	new(InferenceContext self, EObject obj, TypeVariable tv) {
		this(self, obj, tv, self.type);
	}

	new(InferenceContext self, EObject obj, AbstractType type) {
		this(self, obj, self.tv, type);
	}
	
	new(InferenceContext self, TypeVariable tv, AbstractType type) {
		this(self, self.obj, tv, type);
	}
	new(InferenceContext self, EObject obj, TypeVariable tv, AbstractType type) {
		this(self.system, self.r, obj, tv, type);
	}
	
	override toString() {
		return '''«obj» :: «tv» := «type»''';
	}
}

class NullSizeInferrer extends AbstractSizeInferrer implements TypeSizeInferrer {
		
	override createConstraints(InferenceContext c) {
	}
	
	override setDelegate(TypeSizeInferrer delegate) {
	}
		
	override createSizeConstraints(ConstraintSolution cs, Resource r) {
		return cs;
	}
	
	override unbindSize(Resource r, ConstraintSystem system, EObject obj, AbstractType type) {
		return type -> #[];
	}
	
	override createConstraintsForMax(ConstraintSystem system, Resource r, MaxConstraint constraint) {
	}
	
	override isFixedSize(TypeSpecifier ts) {
		return false;
	}
	
	override createConstraintsForSum(ConstraintSystem system, Resource r, SumConstraint constraint) {
	}
	
	override getZeroSizeType(InferenceContext c, AbstractType skeleton) {
		return skeleton;
	}
	
	override wrap(InferenceContext c, EObject obj, AbstractType inner) {
		return inner;
	}
	
	override validateSolution(ConstraintSolution cs, Resource r) {
		return cs;
	}
	
	override validateSizeInference(Resource r, ConstraintSystem system, EObject origin, AbstractType type) {
		return #[];
	}
	
}