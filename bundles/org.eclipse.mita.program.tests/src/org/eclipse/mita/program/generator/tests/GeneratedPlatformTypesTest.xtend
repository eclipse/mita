package org.eclipse.mita.program.generator.tests

import org.eclipse.cdt.core.dom.ast.IASTElaboratedTypeSpecifier
import org.eclipse.cdt.core.dom.ast.IASTSimpleDeclaration
import org.junit.Test

import static org.junit.Assert.assertFalse
import static org.junit.Assert.assertEquals

class GeneratedPlatformTypesTest extends AbstractGeneratorTest {
	@Test
	def testGeneratedTypesBeingGenerated() {
		val ast = generateAndParseApplication('''
			package test;
			import platforms.unittest;
			
			every 1 second {
				
			}
		''', 'base/generatedTypes/string.h');
		ast.assertNoCompileErrors();
		val parsedProgram = ast.value;
		val stringDeclaration = parsedProgram.declarations
			.filter(IASTSimpleDeclaration)
			.map[it.declSpecifier]
			.filter(IASTElaboratedTypeSpecifier)
			.map[it.name]
			.map[it.toString]
			.filter[it == "array_char"].toList;
		assertEquals(1, stringDeclaration.size);
		return;
	}
}
