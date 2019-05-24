/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.program.formatting

import com.google.inject.Inject
import org.eclipse.mita.program.services.ProgramDslGrammarAccess
import org.eclipse.xtext.formatting.impl.AbstractDeclarativeFormatter
import org.eclipse.xtext.formatting.impl.FormattingConfig
import org.eclipse.xtext.service.AbstractElementFinder.AbstractParserRuleElementFinder

class ProgramDslFormatter extends AbstractDeclarativeFormatter {

	@Inject extension ProgramDslGrammarAccess grammar;

	override protected configureFormatting(FormattingConfig c) {
		c.setAutoLinewrap(120);
		c.formatCurlyBrackets
		c.formatRoundBrackets
		c.formatSemicolon
		c.formatComma
		c.formatComments
		c.formatTypeDeclaration
		c.formatGeneratedType
		c.formatStructureField
		c.formatEnumerator
		c.formatGeneratedFunctionDefinition
		c.formatFeatureCalls
		c.formatIfElse
		c.formatForLoop
		c.formatCatchFinally
		c.formatAllTypeSpecifiers
		c.formatPostFixExpression
	}
	
	def formatCurlyBrackets(FormattingConfig config) {
		grammar.findKeywordPairs("{", "}").forEach [
			config.setLinewrap(1, 1, 2).after(it.first);
			config.setIndentationIncrement().after(it.first);
			config.setLinewrap(1, 1, 2).before(it.second);
			config.setIndentationDecrement().before(it.second);
			config.setLinewrap(1, 1, 2).after(it.second)
		]
	}

	def formatRoundBrackets(FormattingConfig config) {
		grammar.findKeywords("(").forEach [
			config.setNoSpace.before(it)
			config.setNoSpace.after(it)
		]
		grammar.findKeywords(")").forEach [
			config.setNoSpace.before(it)
		]
	}

	def formatSemicolon(FormattingConfig config) {
		grammar.findKeywords(";").forEach [
			config.setLinewrap(1, 1, 2).after(it)
			config.setNoSpace.before(it)
		]
	}

	def formatComma(FormattingConfig config) {
		grammar.findKeywords(",").forEach [
			config.setNoSpace.before(it)
		]
	}

	def formatComments(FormattingConfig config) {
		config.setLinewrap(0, 1, 2).before(grammar.SL_COMMENTRule)
		config.setLinewrap(0, 1, 2).after(grammar.SL_COMMENTRule)
		config.setLinewrap(0, 1, 2).before(grammar.ML_COMMENTRule)
		config.setLinewrap(0, 1, 1).after(grammar.ML_COMMENTRule)
	}

	def formatTypeDeclaration(FormattingConfig config) {
		config.setLinewrap(0, 1, 2).before(grammar.nativeTypeDeclarationRule)
		config.setLinewrap(0, 1, 2).before(grammar.structureTypeDeclarationRule)
		config.setLinewrap(0, 1, 2).before(grammar.exceptionTypeDeclarationRule)
		config.setLinewrap(0, 1, 2).before(grammar.enumerationDeclarationRule)
		config.setLinewrap(0, 1, 2).before(grammar.generatedTypeRule)
	}

	def formatAllTypeSpecifiers(FormattingConfig config) {
		grammar.variableDeclarationAccess.formatTypeSpecifier
		grammar.generatedTypeAccess.formatTypeSpecifier
		grammar.generatedFunctionDefinitionAccess.formatTypeSpecifier
		grammar.functionDefinitionAccess.formatTypeSpecifier
		grammar.structureFieldAccess.formatTypeSpecifier
		grammar.anonymousProductTypeAccess.formatTypeSpecifier
		grammar.productMemberAccess.formatTypeSpecifier
	}
	
	protected def formatTypeSpecifier(AbstractParserRuleElementFinder access) {
		access.findKeywordPairs("<", ">").forEach [ k |
			config.setNoSpace.after(k.first)
			config.setNoSpace.before(k.first)
			config.setSpace(" ").before(k.second)
		]
	} 

	def formatGeneratedType(FormattingConfig config) {
		config.setIndentationIncrement.before(grammar.generatedTypeAccess.generatorKeyword_6)
		config.setLinewrap(1, 1, 2).before(grammar.generatedTypeAccess.generatorKeyword_6)
		config.setLinewrap(1, 1, 2).before(grammar.generatedTypeAccess.sizeInferrerKeyword_8)
		config.setLinewrap(1, 1, 2).before(grammar.generatedTypeAccess.validatorKeyword_10_0)
		config.setLinewrap(1, 1, 2).before(grammar.generatedTypeConstructorRule)
		config.setIndentationDecrement.after(grammar.generatedTypeAccess.semicolonKeyword_12)
	}

	def formatStructureField(FormattingConfig config) {
		config.setLinewrap(1, 1, 2).before(grammar.structureFieldRule)
	}

	def formatEnumerator(FormattingConfig config) {
		config.setLinewrap(0, 0, 1).before(grammar.enumeratorRule)
	}

	def formatIfElse(FormattingConfig config) {
		config.setNoLinewrap.before(grammar.ifStatementAccess.elseKeyword_6_0)
		config.setNoLinewrap.before(grammar.ifStatementAccess.elseIfAssignment_5)
	}

	def formatCatchFinally(FormattingConfig config) {
		config.setNoLinewrap.before(grammar.tryStatementAccess.finallyKeyword_3_0)
		config.setNoLinewrap.before(grammar.tryStatementAccess.catchStatementsAssignment_2)
	}

	def formatForLoop(FormattingConfig config) {
		grammar.abstractLoopStatementAccess.findKeywords(";").forEach[config.setNoLinewrap.after(it)]
	}

	def formatGeneratedFunctionDefinition(FormattingConfig config) {
		config.setIndentationIncrement.before(grammar.generatedFunctionDefinitionAccess.generatorKeyword_9_0_0)
		config.setLinewrap(1, 1, 2).before(grammar.generatedFunctionDefinitionAccess.generatorKeyword_9_0_0)
		config.setIndentationIncrement.before(grammar.generatedFunctionDefinitionAccess.generatorKeyword_9_1_0_1_0)
		config.setLinewrap(1, 1, 2).before(grammar.generatedFunctionDefinitionAccess.generatorKeyword_9_1_0_1_0)
		config.setLinewrap(1, 1, 2).before(grammar.generatedFunctionDefinitionAccess.validatorKeyword_9_1_2_0_0)
		config.setLinewrap(1, 1, 2).before(grammar.generatedFunctionDefinitionAccess.sizeInferrerKeyword_9_1_1_0)
		config.setIndentationDecrement.after(grammar.generatedFunctionDefinitionAccess.semicolonKeyword_10);
	}

	def formatFeatureCalls(FormattingConfig config) {
		grammar.findKeywords(".").forEach[config.setNoSpace.around(it)]
	}
	
	def formatPostFixExpression(FormattingConfig config) {
		config.setNoSpace.before(grammar.postFixUnaryExpressionAccess.operatorPostFixOperatorEnumRuleCall_1_1_0)
	}

}
