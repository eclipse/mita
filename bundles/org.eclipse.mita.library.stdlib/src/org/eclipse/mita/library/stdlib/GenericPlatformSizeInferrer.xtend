package org.eclipse.mita.library.stdlib

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.types.Variance
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.infra.ElementSizeInferrer
import org.eclipse.mita.base.typesystem.infra.FunctionSizeInferrer
import org.eclipse.mita.base.typesystem.infra.InferenceContext
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.LiteralNumberType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.platform.Signal
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.xtend.lib.annotations.Accessors

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import static extension org.eclipse.mita.base.util.BaseUtils.init
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.base.types.NamedElement
import org.eclipse.mita.library.stdlib.functions.SignalInstanceSizeInferrer

/**
 * This inferrer can handle all types in the stdlib, so if you're returning 
 * - an array<T, size>, where T is structural, 
 * - or string<size> you can use this.
 * Just override getLengthParameterName with the name of your length parameter.
 */
class GenericPlatformSizeInferrer implements FunctionSizeInferrer {
	@Inject
	ArraySizeInferrer arrayDelegate;
	@Accessors
	ElementSizeInferrer delegate;
	@Inject
	StdlibTypeRegistry typeRegistry;
	
	override createConstraints(InferenceContext c) {
		doCreateConstraints(c, c.obj, c.type);
	}
	
	
	def String getLengthParameterName(SignalInstance sigInst) {
		return 'length';
	}
	

	
	protected dispatch def void doCreateConstraints(InferenceContext c, SignalInstance instance, TypeConstructorType type) {
		if(!#["string", "array"].contains(type.name)) {
			return;
		}
		
		val lengthArg = ModelUtils.getArgumentValue(instance, instance.lengthParameterName);
		if(lengthArg !== null) {
			val maxLength = StaticValueInferrer.infer(lengthArg, [ ])?.castOrNull(Long);
			if(maxLength !== null) {
				val u32 = typeRegistry.getTypeModelObject(instance, StdlibTypeRegistry.u32TypeQID);
				// sigInst has type resource -> sigInst<string<Size>>
				// create string<'10>
				val innerReturnType = new TypeConstructorType(instance, type.name, 
					type.typeArgumentsAndVariances.init + #[
						new LiteralNumberType(lengthArg, maxLength, c.system.getTypeVariable(u32)) as AbstractType -> 
						Variance.COVARIANT
					] 
				);
				// create sigInst<string<'10>>
				val returnType = SignalInstanceSizeInferrer.wrapInSigInst(c, typeRegistry, innerReturnType);
				val signal = instance.initialization?.castOrNull(ElementReferenceExpression)?.reference?.castOrNull(Signal);
				val setup = EcoreUtil2.getContainerOfType(instance, SystemResourceSetup);
				val systemResource = setup?.type;
		
				val signalTv = c.system.getTypeVariable(signal);
				val sigInstFunName = signal?.name + "_inst";
				// create resource -> sigInst<string<'10>>
				val sigInstSetupType = new FunctionType(
					null, 
					new AtomicType(instance, sigInstFunName), 
					new ProdType(null, new AtomicType(instance, "__args"), #[c.system.getTypeVariable(systemResource)]), 
					returnType
				);
//				c.system.addConstraint(new EqualityConstraint(sigInstSetupType, signalTv, new ValidationIssue('''''', c.obj)))
				// type sigInst
				c.system.associate(sigInstSetupType, instance);
			}			
		}
		
		return;
	}	
	
	// call delegate for other things
	protected dispatch def void doCreateConstraints(InferenceContext c, EObject obj, AbstractType type) {
		delegate.createConstraints(c);
	}
		
	override setDelegate(ElementSizeInferrer delegate) {
		this.delegate = delegate;
		arrayDelegate.delegate = delegate;
	}	
}
