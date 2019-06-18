package org.eclipse.mita.library.stdlib.functions

import com.google.inject.Inject
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.typesystem.infra.ElementSizeInferrer
import org.eclipse.mita.base.typesystem.infra.FunctionSizeInferrer
import org.eclipse.mita.base.typesystem.infra.InferenceContext
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.program.resource.PluginResourceLoader
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.EcoreUtil2

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.inferrer.ProgramSizeInferrer
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.platform.Signal
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.types.Variance

class SignalInstanceSizeInferrer implements FunctionSizeInferrer {
	@Accessors
	ElementSizeInferrer delegate
	
	@Inject
	protected PluginResourceLoader loader
	
	@Inject
	StdlibTypeRegistry typeRegistry
	
	static def wrapInSigInst(InferenceContext c, StdlibTypeRegistry typeRegistry, AbstractType t) {
		val sigInstTypeObject = typeRegistry.getTypeModelObject(c.obj, StdlibTypeRegistry.sigInstTypeQID);
		// \T. sigInst<T>
		val sigInstType = c.system.getTypeVariable(sigInstTypeObject);
		// t0 ~ sigInst<t>
		val sigInstInstance = c.system.newTypeVariable(c.obj);
		// t0 instanceof \T. sigInst<T> => creates t0 := sigInst<t1>
		c.system.addConstraint(new ExplicitInstanceConstraint(sigInstInstance, sigInstType, new ValidationIssue('''%s is not instance of %s''', c.obj)));
		// bind sigInst<t> to t0
		c.system.addConstraint(new EqualityConstraint(sigInstInstance, new TypeConstructorType(c.obj, "siginst", #[new AtomicType(sigInstTypeObject, "siginst") -> Variance.INVARIANT, t -> Variance.INVARIANT]), new ValidationIssue('''%s is not instance of %s''', c.obj)))
		// return t0 ~ sigInst<t>
		return sigInstInstance;
	}
	
	// type setup.x.read()
	override createConstraints(InferenceContext c) {
		val funCall = c.obj.castOrNull(ElementReferenceExpression);
		val sigInstRef = funCall?.arguments?.head?.value?.castOrNull(ElementReferenceExpression);
		val sigInst = sigInstRef?.reference;
		// getContainerOfType is null safe
		val setup = EcoreUtil2.getContainerOfType(sigInst, SystemResourceSetup);
		val systemResource = setup?.type;
		val sizeInferrerCls = systemResource?.sizeInferrer;
		val sizeInferrer = if(sizeInferrerCls !== null) { loader.loadFromPlugin(c.r, sizeInferrerCls)?.castOrNull(FunctionSizeInferrer) }
		if(sizeInferrer !== null) {
			sizeInferrer.setDelegate(delegate);
			val innerContext = new InferenceContext(c, sigInst, c.system.getTypeVariable(sigInst));
			sizeInferrer.createConstraints(innerContext);
			// sigInst has type resource -> sigInst<string<Size>>
			val sigInstTv = c.system.getTypeVariable(sigInst); // ~ resource -> sigInst<string<Size>>
			val sigInstInstance = wrapInSigInst(c, typeRegistry, c.type); // ~ sigInst<string<Size>>
			val sigInstFunName = sigInst?.castOrNull(SignalInstance).initialization?.castOrNull(ElementReferenceExpression)?.reference?.castOrNull(Signal)?.name + "_inst";
			// resource -> sigInst<string<Size>>
			val sigInstSetupType = new FunctionType(
				null, 
				new AtomicType(sigInst, sigInstFunName), 
				new ProdType(null, new AtomicType(sigInst, "__args"), #[c.system.getTypeVariable(systemResource)]), 
				sigInstInstance
			);
			// assert that sigInst has type resource -> sigInst<string<Size>>
			c.system.addConstraint(new EqualityConstraint(sigInstSetupType, sigInstTv, new ValidationIssue('''''', c.obj)))
			// type c.obj
			c.system.associate(c.type, c.obj);
		}
	}	
}