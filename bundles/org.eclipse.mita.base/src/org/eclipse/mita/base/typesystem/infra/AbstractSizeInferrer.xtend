package org.eclipse.mita.base.typesystem.infra

import com.google.common.base.Optional
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.typesystem.solver.ConstraintSolution
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import java.util.Map

abstract class AbstractSizeInferrer {
	def ConstraintSolution inferSizes(ConstraintSolution cs, Resource r);
}

interface ElementSizeInferrer {
	/**
	 * Unbinds type arguments etc. that represent sizes.
	 * If nothing is unbound, an empty #{} should be returned.
	 * Otherwise implementers return at least one unit of work, an inference context.
	 * Additional entries may be created, for example:
	 * tv = f_0, t = u8 -> array<u8, _>
	 * #{
	 * 	f_0: u8 -> f_1
	 * 	f_1: array<u8, f_2>
	 * }
	 */
	def Iterable<InferenceContext> unbindSize(InferenceContext c) {
		return #[];
	}

	/**
	 * Infers the size for EObject obj with type type. It does this by inserting bindings into sub.
	 * If inference succeeds infer must at least insert a binding for c.tv, 
	 * since c.tv was created during unbinding and replaced a binding for c.oldType.
	 * 
	 * @return its arguments if it failed to infer sizes and wants to try again later. 
	 */
	def Optional<InferenceContext> infer(InferenceContext c);
	
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

@FinalFieldsConstructor
@Accessors
class InferenceContext {
	val ConstraintSystem system;
	val Substitution sub;
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
	
	new(InferenceContext self, EObject obj, AbstractType type) {
		this(self.system, self.sub, self.r, obj, self.tv, type);
	}
	
	new(InferenceContext self, TypeVariable tv, AbstractType type) {
		this(self.system, self.sub, self.r, self.obj, tv, type);
	}
	
	override toString() {
		return '''(«obj», «tv» -> «type»)''';
	}
}

class NullSizeInferrer extends AbstractSizeInferrer implements ElementSizeInferrer {
	
	override inferSizes(ConstraintSolution cs, Resource r) {
		return cs;
	}
	
	override Optional<InferenceContext> infer(InferenceContext c) {
		return Optional.absent();
	}
	
	override setDelegate(ElementSizeInferrer delegate) {
	}
	
	override max(ConstraintSystem system, Resource r, EObject objOrProxy, Iterable<AbstractType> types) {
		return Optional.absent;
	}
	
}