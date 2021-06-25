package org.eclipse.mita.program.tests.unit

import com.google.inject.Guice
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.TypeUtils
import org.eclipse.mita.base.types.Variance
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.program.generator.AbstractTypeGenerator
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator
import org.eclipse.mita.program.generator.internal.GeneratorRegistry
import org.eclipse.mita.program.generator.internal.ProgramCopier
import org.eclipse.xtext.scoping.IScopeProvider
import org.mockito.Mock

import static org.junit.Assert.assertEquals
import static org.mockito.ArgumentMatchers.*
import static org.mockito.Mockito.mock
import static org.mockito.Mockito.when

import static extension org.eclipse.mita.program.tests.util.TestUtils.mockBind
import org.junit.runner.RunWith
import org.junit.Before
import org.junit.Test
import static org.mockito.Mockito.RETURNS_DEEP_STUBS

class GeneratorUtilsTest {
	GeneratorUtils subject;
	GeneratorRegistry generatorRegistry;
	TypeUtils typeUtils;

	@Before
	def void setup() {
		val injector = Guice.createInjector([ b |
			b.mockBind(ProgramCopier)
			b.mockBind(IScopeProvider)
			generatorRegistry = b.mockBind(GeneratorRegistry)
			b.mockBind(CodeFragmentProvider)
			b.mockBind(IPlatformLoggingGenerator)
			typeUtils = b.mockBind(TypeUtils)
		]);
		subject = injector.getInstance(GeneratorUtils);
	}

	@Test
	def void testGetFileNameForTypeImplementation() {
		var context = mock(EObject, RETURNS_DEEP_STUBS)
		
		var t0 = new ProdType(context, "t0", #[])
		var t1 = new SumType(context, "t1", #[])
		var t2Ref = new AtomicType(context, "t2")
		var t2 = new TypeConstructorType(context, "t2", #[t2Ref -> Variance.INVARIANT, t0 -> Variance.INVARIANT, t1 -> Variance.INVARIANT])
		
		when(typeUtils.isGeneratedType(eq(context), any())).thenReturn(false)
		when(typeUtils.isGeneratedType(context, t2)).thenReturn(true)

		assertEquals("t0", subject.getFileNameForTypeImplementation(context, t0))
		assertEquals("t1", subject.getFileNameForTypeImplementation(context, t1))
		// default implementation: use all (but first) type arg
		assertEquals("t2_t0_t1", subject.getFileNameForTypeImplementation(context, t2))
		
		// generators may override default implementation:
		var generator = mock(AbstractTypeGenerator)

		when(generatorRegistry.getGenerator(context.eResource, t2)).thenReturn(generator)
		when(generator.generateHeaderName(context, t2)).thenReturn("t2custom")
		
		assertEquals("t2custom", subject.getFileNameForTypeImplementation(context, t2))
	}
}
