package org.eclipse.mita.base.typesystem.infra

import com.google.common.base.Optional
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.typesystem.solver.ConstraintSolution
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType

abstract class AbstractSizeInferrer {
	def ConstraintSolution inferSizes(ConstraintSolution cs, Resource r);
}

interface ElementSizeInferrer {
	// default: identity/snd
	def AbstractType unbindSize(ConstraintSystem system, AbstractType t) {
		return t;
	}

	/**
	 * Infers the size for EObject obj with type type. It does this by inserting bindings into sub.
	 * 
	 * @param type the type of obj from which the size argument(s) have already been unbound.
	 * @return its arguments if it failed to infer sizes and wants to try again later.
	 */
	def Optional<Pair<EObject, AbstractType>> infer(ConstraintSystem system, Substitution sub, Resource r, EObject obj, AbstractType type);	
	
	/**
	 * allows delegating calls to global implementation. 
	 * May only call delegate.infer on the passed EObject and its contained objects, not on references or containers.
	 * In fact, calling delegate.infer should be the default action of inferrers that are not some kind of "main" inferrer.
	 */
	def void setDelegate(ElementSizeInferrer delegate);
	
	/**
	 * Finds the maximum size of all passed types.
	 * 
	 * @return Optional.absent, if its not (yet) possible to compute the maximum.
	 */
	def Optional<AbstractType> max(ConstraintSystem system, Resource r, EObject objOrProxy, Iterable<AbstractType> types);
}

class NullSizeInferrer extends AbstractSizeInferrer implements ElementSizeInferrer {
	
	override inferSizes(ConstraintSolution cs, Resource r) {
		return cs;
	}
	
	override infer(ConstraintSystem system, Substitution sub, Resource r, EObject obj, AbstractType type) {
		return Optional.absent();
	}
	
	override setDelegate(ElementSizeInferrer delegate) {
	}
	
	override max(ConstraintSystem system, Resource r, EObject objOrProxy, Iterable<AbstractType> types) {
		return Optional.absent;
	}
	
}