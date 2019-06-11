package org.eclipse.mita.library.stdlib

import com.google.common.base.Optional
import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.typesystem.infra.ElementSizeInferrer
import org.eclipse.mita.base.typesystem.infra.InferenceContext
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.LiteralNumberType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull

/**
 * This inferrer can handle all types in the stdlib, so if you're returning an array<T, size> or string<size> you can use this.
 */
class GenericPlatformSizeInferrer implements ElementSizeInferrer {
	@Inject
	ArraySizeInferrer arrayDelegate;
	ElementSizeInferrer delegate;
	
	def String getLengthParameterName(SignalInstance sigInst) {
		return 'length';
	}
	
	override Optional<InferenceContext> infer(InferenceContext c) {
		return doInfer(c, c.obj, c.type);
	}
		
	protected dispatch def Optional<InferenceContext> doInfer(InferenceContext c, SignalInstance instance, TypeConstructorType type) {
		if(!#["string", "array"].contains(type.name)) {
			return Optional.absent();
		}
		
		val lengthArg = ModelUtils.getArgumentValue(instance, instance.lengthParameterName);
		if(lengthArg !== null) {
			val maxLength = StaticValueInferrer.infer(lengthArg, [ ])?.castOrNull(Long);
			if(maxLength !== null) {
				arrayDelegate.replaceLastTypeArgument(c.sub, type, new LiteralNumberType(lengthArg, maxLength, BaseUtils.getType(c.system, c.sub, lengthArg)))
			}
		}
		
		return Optional.absent;
	}	
	
	// call delegate for other things
	protected dispatch def Optional<InferenceContext> doInfer(InferenceContext c, EObject obj, TypeConstructorType type) {
		return delegate.infer(c);
	}
	
	// error/wait if type is not TypeConstructorType
	protected dispatch def Optional<InferenceContext> doInfer(InferenceContext c, EObject obj, AbstractType type) {
		return Optional.of(c);
	}
	
	override setDelegate(ElementSizeInferrer delegate) {
		this.delegate = delegate;
		arrayDelegate.delegate = delegate;
	}
	
	override max(ConstraintSystem system, Resource r, EObject objOrProxy, Iterable<AbstractType> types) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
}
