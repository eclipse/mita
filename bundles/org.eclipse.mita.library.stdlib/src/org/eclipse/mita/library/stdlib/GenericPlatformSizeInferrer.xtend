package org.eclipse.mita.library.stdlib

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.types.Variance
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.infra.FunctionSizeInferrer
import org.eclipse.mita.base.typesystem.infra.InferenceContext
import org.eclipse.mita.base.typesystem.infra.TypeSizeInferrer
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.LiteralNumberType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.library.stdlib.functions.SignalInstanceSizeInferrer
import org.eclipse.mita.platform.Signal
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.EventHandlerVariableDeclaration
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemEventSource
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.EcoreUtil2

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import static extension org.eclipse.mita.base.util.BaseUtils.init
import org.eclipse.mita.program.inferrer.ProgramSizeInferrer
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem

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
	TypeSizeInferrer delegate;
	@Inject
	StdlibTypeRegistry typeRegistry;
	
	override createConstraints(InferenceContext c) {
		doCreateConstraints(c, c.obj, c.type);
	}
	
	
	def String getLengthParameterName(SignalInstance sigInst) {
		return 'length';
	}
	
	protected def AbstractType computeSigInstDataType(ConstraintSystem system, SignalInstance instance, TypeConstructorType scheme) {
		if(!#["string", "array"].contains(scheme.name)) {
			return null;
		}
		val lengthArg = ModelUtils.getArgumentValue(instance, instance.lengthParameterName);
		if(lengthArg !== null) {
			val maxLength = StaticValueInferrer.infer(lengthArg, [ ])?.castOrNull(Long);
			if(maxLength !== null) {
				val u32 = typeRegistry.getTypeModelObject(instance, StdlibTypeRegistry.u32TypeQID);
				// sigInst has type resource -> sigInst<string<Size>>
				// create string<'10>
				val innerReturnType = new TypeConstructorType(instance, scheme.name, 
					scheme.typeArgumentsAndVariances.init + #[
						new LiteralNumberType(lengthArg, maxLength, system.getTypeVariable(u32)) as AbstractType -> 
						Variance.COVARIANT
					] 
				);
				return innerReturnType;	
			}
		}
	}
	
	protected dispatch def void doCreateConstraints(InferenceContext c, SystemEventSource eventSource, TypeConstructorType type) {
		if(eventSource.signalInstance !== null) {
			// we already type this via the eventVariable
			return;
		}
		delegate.createConstraints(c);
	}
	protected dispatch def void doCreateConstraints(InferenceContext c, EventHandlerVariableDeclaration eventVariable, TypeConstructorType type) {
		// if event is part of a signal instance, its initialization could have a size argument which we will use here 
		if(!#["string", "array"].contains(type.name)) {
			return;
		}
		val eventSource = EcoreUtil2.getContainerOfType(eventVariable, EventHandlerDeclaration)?.event;
		val signalInstance = eventSource?.castOrNull(SystemEventSource)?.signalInstance;
		if(signalInstance !== null) {
			doCreateConstraints(c, signalInstance, type);
			ProgramSizeInferrer.inferUnmodifiedFrom(c.system, eventSource, eventVariable);
			// signal instance is now typed. Next we need to extract its size
			val typeWithSize = computeSigInstDataType(c.system, signalInstance, type);
			c.system.associate(typeWithSize, eventVariable);
		}
	}
	
	protected dispatch def void doCreateConstraints(InferenceContext c, SignalInstance instance, TypeConstructorType type) {
		if(!#["string", "array"].contains(type.name)) {
			return;
		}
		
		val innerReturnType = computeSigInstDataType(c.system, instance, type);
		if(innerReturnType !== null) {
			// create sigInst<string<'10>>
			val returnType = SignalInstanceSizeInferrer.wrapInSigInst(c, typeRegistry, innerReturnType);
			val signal = instance.initialization?.castOrNull(ElementReferenceExpression)?.reference?.castOrNull(Signal);
			val setup = EcoreUtil2.getContainerOfType(instance, SystemResourceSetup);
			val systemResource = setup?.type;
	
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
		
		return;
	}	
	
	// call delegate for other things
	protected dispatch def void doCreateConstraints(InferenceContext c, EObject obj, AbstractType type) {
		delegate.createConstraints(c);
	}
		
	override setDelegate(TypeSizeInferrer delegate) {
		this.delegate = delegate;
		arrayDelegate.delegate = delegate;
	}	
}
