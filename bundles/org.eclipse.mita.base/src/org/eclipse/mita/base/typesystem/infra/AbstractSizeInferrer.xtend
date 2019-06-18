package org.eclipse.mita.base.typesystem.infra

import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.typesystem.constraints.MaxConstraint
import org.eclipse.mita.base.typesystem.solver.ConstraintSolution
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

abstract class AbstractSizeInferrer {
	def ConstraintSolution createSizeConstraints(ConstraintSolution cs, Resource r);
}

interface FunctionSizeInferrer {
	/**
	 * allows delegating calls to global implementation. 
	 * May only call delegate.infer on the passed EObject and its contained objects, not on references or containers.
	 * In fact, calling delegate.infer should be the default action of inferrers that are not some kind of "main" inferrer.
	 */
	def void setDelegate(ElementSizeInferrer delegate);
	/**
	 * Infers the size for EObject obj with type type. It does this by inserting constraints into c.system.
	 */
	def void createConstraints(InferenceContext c);
}

interface ElementSizeInferrer extends FunctionSizeInferrer {
	/**
	 * Unbinds size parameters in types of objects.
	 */
	def Pair<AbstractType, Iterable<EObject>> unbindSize(Resource r, ConstraintSystem system, EObject obj, AbstractType type);
		
	/**
	 * Finds the maximum size of all passed types.
	 */
	def void createConstraintsForMax(ConstraintSystem system, Resource r, MaxConstraint constraint);
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

class NullSizeInferrer extends AbstractSizeInferrer implements ElementSizeInferrer {
		
	override createConstraints(InferenceContext c) {
	}
	
	override setDelegate(ElementSizeInferrer delegate) {
	}
		
	override createSizeConstraints(ConstraintSolution cs, Resource r) {
		return cs;
	}
	
	override unbindSize(Resource r, ConstraintSystem system, EObject obj, AbstractType type) {
		return type -> #[];
	}
	
	override createConstraintsForMax(ConstraintSystem system, Resource r, MaxConstraint constraint) {
	}
	
}