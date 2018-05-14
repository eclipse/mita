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

package org.eclipse.mita.program.generator

import org.eclipse.mita.platform.Modality
import org.eclipse.mita.program.AbstractStatement
import org.eclipse.mita.program.ArrayAccessExpression
import org.eclipse.mita.program.ArrayLiteral
import org.eclipse.mita.program.ArrayRuntimeCheckStatement
import org.eclipse.mita.program.DereferenceExpression
import org.eclipse.mita.program.DoWhileStatement
import org.eclipse.mita.program.ExceptionBaseVariableDeclaration
import org.eclipse.mita.program.ExpressionStatement
import org.eclipse.mita.program.ForEachStatement
import org.eclipse.mita.program.ForStatement
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.IfStatement
import org.eclipse.mita.program.InterpolatedStringExpression
import org.eclipse.mita.program.IsAssignmentCase
import org.eclipse.mita.program.IsDeconstructionCase
import org.eclipse.mita.program.IsDeconstructor
import org.eclipse.mita.program.IsOtherCase
import org.eclipse.mita.program.IsTypeMatchCase
import org.eclipse.mita.program.LoopBreakerStatement
import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.NativeFunctionDefinition
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.ReferenceExpression
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SourceCodeComment
import org.eclipse.mita.program.ThrowExceptionStatement
import org.eclipse.mita.program.TryStatement
import org.eclipse.mita.program.ValueRange
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.WhereIsStatement
import org.eclipse.mita.program.WhileStatement
import org.eclipse.mita.program.generator.internal.GeneratorRegistry
import org.eclipse.mita.program.inferrer.ElementSizeInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.types.AnonymousProductType
import org.eclipse.mita.types.GeneratedType
import org.eclipse.mita.types.NamedProductType
import org.eclipse.mita.types.Singleton
import org.eclipse.mita.types.StructureType
import org.eclipse.mita.types.SumAlternative
import org.eclipse.mita.types.SumType
import com.google.inject.Inject
import java.util.LinkedList
import java.util.List
import java.util.function.Function
import org.eclipse.core.runtime.CoreException
import org.eclipse.core.runtime.IStatus
import org.eclipse.core.runtime.Status
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend2.lib.StringConcatenationClient
import org.eclipse.xtext.generator.trace.node.IGeneratorNode
import org.eclipse.xtext.generator.trace.node.Traced
import org.yakindu.base.expressions.expressions.Argument
import org.yakindu.base.expressions.expressions.ArgumentExpression
import org.yakindu.base.expressions.expressions.AssignmentExpression
import org.yakindu.base.expressions.expressions.AssignmentOperator
import org.yakindu.base.expressions.expressions.BinaryExpression
import org.yakindu.base.expressions.expressions.BoolLiteral
import org.yakindu.base.expressions.expressions.ConditionalExpression
import org.yakindu.base.expressions.expressions.DoubleLiteral
import org.yakindu.base.expressions.expressions.ElementReferenceExpression
import org.yakindu.base.expressions.expressions.Expression
import org.yakindu.base.expressions.expressions.FeatureCall
import org.yakindu.base.expressions.expressions.FloatLiteral
import org.yakindu.base.expressions.expressions.HexLiteral
import org.yakindu.base.expressions.expressions.IntLiteral
import org.yakindu.base.expressions.expressions.Literal
import org.yakindu.base.expressions.expressions.NullLiteral
import org.yakindu.base.expressions.expressions.ParenthesizedExpression
import org.yakindu.base.expressions.expressions.PostFixUnaryExpression
import org.yakindu.base.expressions.expressions.PrimitiveValueExpression
import org.yakindu.base.expressions.expressions.StringLiteral
import org.yakindu.base.expressions.expressions.TypeCastExpression
import org.yakindu.base.expressions.expressions.UnaryExpression
import org.yakindu.base.types.EnumerationType
import org.yakindu.base.types.Operation
import org.yakindu.base.types.Parameter
import org.yakindu.base.types.PrimitiveType
import org.yakindu.base.types.Property
import org.yakindu.base.types.TypeSpecifier
import org.yakindu.base.types.TypesFactory
import org.yakindu.base.types.inferrer.ITypeSystemInferrer
import org.eclipse.xtext.generator.trace.node.CompositeGeneratorNode
import org.yakindu.base.types.inferrer.ITypeSystemInferrer.InferenceResult

class StatementGenerator {

	@Inject extension ProgramDslTraceExtensions

	@Inject ITypeSystemInferrer typeInferrer
	
	@Inject
	protected extension GeneratorUtils

	@Inject
	protected TypeGenerator typeGenerator

	@Inject(optional=true)
	protected IPlatformExceptionGenerator exceptionGenerator

	@Inject
	protected CodeFragmentProvider codeFragmentProvider

	@Inject
	protected GeneratorRegistry registry
	
	@Inject
	protected ElementSizeInferrer sizeInferrer

	@Traced dispatch def IGeneratorNode code(Argument stmt) {
		'''«stmt.value.code»'''
	}

	@Traced dispatch def IGeneratorNode code(StringLiteral stmt) {
		'''"«stmt.value»"'''
	}

	@Traced dispatch def code(NullLiteral stmt) {
		'''NULL'''
	}

	@Traced dispatch def IGeneratorNode code(IntLiteral stmt) {
		'''«stmt.value»'''
	}

	@Traced dispatch def IGeneratorNode code(HexLiteral stmt) {
		'''0x«Integer.toHexString(stmt.value)»'''
	}

	@Traced dispatch def IGeneratorNode code(FloatLiteral stmt) {
		'''«stmt.value»f'''
	}

	@Traced dispatch def IGeneratorNode code(DoubleLiteral stmt) {
		'''«stmt.value»f'''
	}

	@Traced dispatch def IGeneratorNode code(BoolLiteral stmt) {
		val result = codeFragmentProvider
			.create('''«IF stmt.value»true«ELSE»false«ENDIF»''')
			.addHeader('stdbool.h', true);
		return '''«result»''';
	}
	
	@Traced dispatch def IGeneratorNode code(ArrayLiteral stmt) {
		'''{«FOR value: stmt.values SEPARATOR(', ')»«value.code»«ENDFOR»}'''
	}
	
	@Traced dispatch def IGeneratorNode code(Literal stmt) {
		'''ERROR: unsupported literal: «stmt»'''
	}

	@Traced dispatch def IGeneratorNode code(UnaryExpression stmt) {
		'''«stmt.operator.literal»«stmt.operand.code»'''
	}
	
	@Traced dispatch def IGeneratorNode code(PostFixUnaryExpression stmt) {
		'''«stmt.operand.code.noTerminator»«stmt.operator.literal»«IF stmt.eContainer instanceof ExpressionStatement»;«ENDIF»'''
	}

	@Traced dispatch def IGeneratorNode code(TypeCastExpression stmt) {
		/* TODO: replace this hack with a typecast expression that supports TypeSpecifier
		 * see https://github.com/Yakindu/statecharts/issues/1779
		 */
		val typeSpec = TypesFactory.eINSTANCE.createTypeSpecifier();
		typeSpec.type = stmt.type;

		'''(«typeGenerator.code(typeSpec)») («stmt.operand.code.noTerminator»)'''
	}

	@Traced dispatch def IGeneratorNode code(PrimitiveValueExpression stmt) {
		'''«stmt.value.code»'''
	}

	@Traced dispatch def IGeneratorNode code(ParenthesizedExpression stmt) {
		'''(«stmt.expression.code.noTerminator»);'''
	}

	@Traced dispatch def IGeneratorNode code(BinaryExpression stmt) {
		// TODO: handle strings and reference types
		'''«stmt.leftOperand.code.noTerminator» «stmt.operator.literal» «stmt.rightOperand.code.noTerminator»;'''
	}

	dispatch def IGeneratorNode code(ModalityAccess stmt) {
		/*
		 * At this point we should have generated code preparing this access.
		 * The generator will expect that, but so far we don't have an explicit
		 * state sharing between sensor access preparation and modality access.
		 */
		val sensor = stmt.preparation.systemResource;
		val generator = registry.getGenerator(sensor);
		generator.generateModalityAccessFor(stmt)
			.addHeader(stmt.preparation.systemResource.fileBasename + '.h', false);
	}

	dispatch def IGeneratorNode code(ModalityAccessPreparation stmt) {
		val sensor = stmt.systemResource;
		val generator = registry.getGenerator(sensor);
		
		// here our generator concept fails us. We are unable to provide all the state to the generator!
		generator.prepare(sensor, null, null, null);
		
		generator.generateAccessPreparationFor(stmt)
			.addHeader(stmt.systemResource.fileBasename + '.h', false);
	}

	@Traced dispatch def IGeneratorNode code(ArrayAccessExpression stmt) {
		val maybeErefExpr = stmt.owner;
		val id = if(maybeErefExpr instanceof ElementReferenceExpression) {
			maybeErefExpr.reference.baseName;
		}
		else {
			maybeErefExpr.uniqueIdentifier;
		}
		
		'''«id».data[«stmt.arraySelector.code.noTerminator»];'''
	}
	
	@Traced dispatch def IGeneratorNode code(ArrayRuntimeCheckStatement stmt) {
		val accessStatement = stmt.access;
		val owner = accessStatement.owner;
		val variableName = if(owner instanceof ElementReferenceExpression) {
			owner.reference.baseName;
		}
		else {
			owner.uniqueIdentifier;
		}
		
		val checks = new LinkedList<CodeFragment>();
		val arraySelector = accessStatement.arraySelector; 
		val arrayLength = '''«variableName».length''';
		if(arraySelector instanceof ValueRange) {			
			if(arraySelector.lowerBound !== null) {
				checks += codeFragmentProvider.create('''«arraySelector.lowerBound.code.noTerminator» < 0''');
			}
			if(arraySelector.upperBound !== null) {
				checks += codeFragmentProvider.create('''«arraySelector.upperBound.code.noTerminator» >= «arrayLength»''');
			}
			if(arraySelector.lowerBound !== null && arraySelector.upperBound !== null) {				
				checks += codeFragmentProvider.create('''«arraySelector.lowerBound.code.noTerminator» > «arraySelector.upperBound.code.noTerminator»''');
			}
		} else {
			checks += codeFragmentProvider.create('''«arrayLength» <= «arraySelector.code.noTerminator»''');
		}

		return '''
		if(«FOR check: checks SEPARATOR(" || ")»«check»«ENDFOR») {
			«generateExceptionHandler(stmt, "EXCEPTION_INVALIDRANGEEXCEPTION")»
		}
		''';
	}

	@Traced dispatch def IGeneratorNode code(FeatureCall stmt) {
		if (stmt.operationCall) {
			val feature = stmt.feature;
			if(feature instanceof SumAlternative) {
				val altAccessor = feature.structName;
				if(!(stmt.owner instanceof ElementReferenceExpression) 
				|| !((stmt.owner as ElementReferenceExpression).reference instanceof SumType)) {
					return '''UNKNOWN ERROR @FeatureCall'''
				}
				val sumType = (stmt.owner as ElementReferenceExpression).reference as SumType;
				val dataType = if(feature instanceof AnonymousProductType) {
					if(feature.typeSpecifiers.length == 1) {
						feature.typeSpecifiers.head.ctype;
					}
					else {
						feature.structType
					}
				}
				else {
					feature.structType
				}
				'''
				(«sumType.structName») {
					.tag = «feature.enumName»«IF !(feature instanceof Singleton)», ««« there is no other field for singletons

					««« (ref instanceof AnonymousProductType => ref.typeSpecifiers.length > 1)

					.data.«altAccessor» = («dataType») {
						«FOR i_arg: stmt.arguments.indexed SEPARATOR(',\n')»
						«accessor(feature, i_arg.value.parameter, ".",  " = ").apply(i_arg.key)»«i_arg.value.value.code.noTerminator»
						«ENDFOR»	
					}
					«ENDIF»
				}
				'''
			} else {
				/* The pogram transformation pipeline rewrites extension methods to regular element reference expressions.
				 * Thus, we should never get here.
				 */
				'''// function calls as feature calls are not supported'''
			}
		} else if (stmt.isArrayAccess) {
			'''«stmt.owner.code.noTerminator»[«stmt.arraySelector.head.code.noTerminator»];'''
		} else if (stmt.feature instanceof Modality) {
			throw new CoreException(new Status(IStatus.ERROR, null, 'Sensor access should not be a feature call'));
		} else if (stmt.feature instanceof SignalInstance) {
			'''/* Signal instance access should have been rewritten by the compiler. */'''
		} else if (stmt.feature instanceof VariableDeclaration) {
			/* This slightly obscure case is for signal read access where the transformation pipeline
			 * replaces the original feature with the SignalInstanceReadAccess variable declaration.
			 */
			val declaration = stmt.feature as VariableDeclaration;
			'''«declaration.name»'''
		} else if (stmt.feature instanceof Property) {
			val _feature = stmt.feature as Property
			'''«stmt.owner.code.noTerminator».«_feature.name»'''
		} else if (stmt.feature instanceof Parameter) {
			val _feature = stmt.feature as Parameter
			'''«stmt.owner.code.noTerminator».«_feature.name»'''
		}
	}

	@Traced dispatch def IGeneratorNode code(ElementReferenceExpression stmt) {
		val ref = stmt.reference
		val id = ref.baseName

		if (stmt.operationCall) {
			if (ref instanceof FunctionDefinition) {
				'''«ref.generateFunctionCall(codeFragmentProvider.create('''NULL''').addHeader("stdlib.h", true), stmt)»'''
			} else if (ref instanceof GeneratedFunctionDefinition) {
				'''«registry.getGenerator(ref)?.generate(stmt, null)»''';
			} else if(ref instanceof NativeFunctionDefinition) {
				if(ref.checked) {
					'''«ref.generateNativeFunctionCallChecked(codeFragmentProvider.create('''NULL'''), stmt)»'''
				} else {
					'''«ref.generateNativeFunctionCallUnchecked(stmt)»'''
				}
			} else if (ref instanceof StructureType) {
				'''
				{
					«FOR i_arg : stmt.arguments.indexed SEPARATOR (',\n')»
					.«IF i_arg.value.parameter !== null»«i_arg.value.parameter.name»«ELSE»«ref.parameters.get(i_arg.key).name»«ENDIF» = «i_arg.value.value.code»
					«ENDFOR»
				}'''
			}  else {
				'''!UNKNOWN REF < EOBJECT!''';
			}
		} else if (stmt.isArrayAccess && !(stmt.arraySelector.head instanceof ValueRange)) {
			
		} else if (id === null) {
			val nameFeature = stmt.reference.eClass.EAllStructuralFeatures.findFirst[x|x.name == 'name'];
			if (nameFeature === null) {
				'''/* unidentified element «stmt.reference» */'''
			} else {
				'''«stmt.reference.eGet(nameFeature)»'''
			}
		} else {
			'''«id»'''
		}
	}

	@Traced dispatch def IGeneratorNode code(DereferenceExpression e) {
		'''(*«e.expression.code»)'''
	}
	
	@Traced dispatch def IGeneratorNode code(ReferenceExpression e) {
		'''(&«e.variable.code»)'''
	}

	@Traced dispatch def IGeneratorNode code(ReturnStatement stmt) {
		val hasValue = stmt.value !== null;
		var AbstractTypeGenerator _generatedTypeGenerator = null;
		var TypeSpecifier _resultType = null;
		if(hasValue) {
			val value = stmt.value;
			val inference = typeInferrer.infer(value);
			val expressionType = inference?.type;
			
			if (expressionType instanceof GeneratedType) {
				_generatedTypeGenerator = registry.getGenerator(expressionType);
				_resultType = ModelUtils.toSpecifier(inference);
			}
		}
		val generatedTypeGenerator = _generatedTypeGenerator;
		val resultType = _resultType;
		
		'''
			«IF hasValue && generatedTypeGenerator !== null»
				«generatedTypeGenerator.generateExpression(resultType, stmt, AssignmentOperator.ASSIGN, stmt.value)»
			«ELSEIF hasValue»
				*_result = «stmt.value.code.noTerminator»;
			«ENDIF» 
			«««If we are in try OR in catch we need to only exit the try/catch block, since we also need to execute finally.
			«IF ModelUtils.isInTryCatchFinally(stmt)»
				returnFromWithinTryCatch = true;
				break;
			«ELSE»
				return exception;
			«ENDIF»
		'''
	}

	@Traced dispatch def IGeneratorNode code(AssignmentExpression stmt) {
		val inference = typeInferrer.infer(stmt);
		val expressionType = inference?.type;
		val expression = stmt.expression;
		
		if (expressionType instanceof GeneratedType) {
			val generator = registry.getGenerator(expressionType);
			val cf = generator.generateExpression(ModelUtils.toSpecifier(inference), stmt.varRef, stmt.operator, stmt.expression);
			return '''«cf»''';
		} else if (expression instanceof ElementReferenceExpression) {
				val reference = expression.reference;
				if (reference instanceof FunctionDefinition) {
				// we're assigning the result of a function call to this variable
				return '''
					«generateFunctionCall(reference as Operation, codeFragmentProvider.create('''&«stmt.varRef.code»'''), expression)»;
				'''
			} else if(reference instanceof NativeFunctionDefinition) {
				if(reference.checked) {
					return '''«reference.generateNativeFunctionCallChecked(codeFragmentProvider.create('''&«stmt.varRef.code»'''), expression)»'''
				}
				else {
					return '''«stmt.varRef.code» «stmt.operator.literal» «reference.generateNativeFunctionCallUnchecked(expression)»;'''
				}
			}
		} 
		
		// Handle everything else
		return '''«stmt.varRef.code.noTerminator» «stmt.operator» «stmt.expression.code.noTerminator»;'''

	}

	@Traced dispatch def IGeneratorNode code(InterpolatedStringExpression stmt) {
		/*
		 * InterpolatedStrings are a special case of an expression where the code generation must be devolved to
		 * the StringGenerator (i.e. the code generator registered at the generated-type string). Inelegantly, we
		 * explicitly encode this case anddevolve code generation the registered code generator of the generated-type. 
		 */
		val typeSpec = ModelUtils.toSpecifier(typeInferrer.infer(stmt));
		val type = typeSpec?.type;
		if (type instanceof GeneratedType) {
			val generator = registry.getGenerator(type);
			if (generator !== null && generator.checkExpressionSupport(typeSpec, null, null)) {
				return '''«generator.generateExpression(typeSpec, stmt, null, null)»''';
			} else {
				throw new CoreException(
					new Status(IStatus.ERROR, "org.eclipse.mita.program",
						'String generator does not support inline interpolation'));
			}
		} else {
			throw new CoreException(
				new Status(IStatus.ERROR, "org.eclipse.mita.program",
					'Interpolated strings should be a generated type'));
		}
	}

	@Traced dispatch def IGeneratorNode code(Expression stmt) {
		'''/* ERROR: unsupported expression «stmt» */'''
	}

	@Traced dispatch def IGeneratorNode code(ExpressionStatement stmt) {
		'''«stmt.expression.code.noTerminator»;'''
	}
	
	
	def IGeneratorNode generateFunCallStmt(String variableName, TypeSpecifier inferenceResult, ElementReferenceExpression initialization) {
		val reference = initialization.reference;
		if (reference instanceof FunctionDefinition) {
			codeFragmentProvider.create('''
				«generateFunctionCall(reference, codeFragmentProvider.create('''&«variableName»'''), initialization)»
			''')
		} else if (reference instanceof GeneratedFunctionDefinition) {
			codeFragmentProvider.create('''
				«registry.getGenerator(reference).generate(initialization, variableName).noTerminator»;
			''')
		} else if(reference instanceof NativeFunctionDefinition) {
			if(reference.checked) {
				codeFragmentProvider.create('''
				«reference.generateNativeFunctionCallChecked(codeFragmentProvider.create('''&«variableName»'''), initialization)»
				''')
			}
			else {
				codeFragmentProvider.create('''
				«variableName» = «reference.generateNativeFunctionCallUnchecked(initialization)»;''')
			}
		}	
	}
	
	dispatch def IGeneratorNode code(VariableDeclaration stmt) {
		// «platformGenerator.typeGenerator.code(stmt.typeSpecifier)»
		val initialization = stmt.initialization;
		val inferenceResult = stmt.inferType;
		val type = inferenceResult?.type;
	
		
	
		// Generated types
		var IGeneratorNode result = null;
		if (type instanceof GeneratedType) {
			val generator = registry.getGenerator(type);
			val typeSpec = ModelUtils.toSpecifier(typeInferrer.infer(stmt));
			var result2 = stmt.trace;
			result2.children += generator.generateVariableDeclaration(inferenceResult, stmt);
			if (initialization instanceof NewInstanceExpression) {
				result2.children += generator.generateNewInstance(typeSpec, initialization);
			} else if (initialization instanceof ArrayAccessExpression) {
				val op = AssignmentOperator.ASSIGN;
				result2.children += generator.generateExpression(typeSpec, stmt, op, initialization);
			} else if (initialization instanceof ElementReferenceExpression) {
				if(initialization.isOperationCall) {
					result2.children += generateFunCallStmt(stmt.name, inferenceResult, initialization);
				}
			}
			result = result2;
		// Exception base variable
		} else if (stmt instanceof ExceptionBaseVariableDeclaration) {
			result = codeFragmentProvider.create('''
				«exceptionGenerator.exceptionType» «stmt.name» = NO_EXCEPTION;
				«IF stmt.needsReturnFromTryCatch»
					bool returnFromWithinTryCatch = false;
				«ENDIF»
				
			''').addHeader('stdbool.h', true)

		// Assignment from functions
		} else if (initialization instanceof ElementReferenceExpression) {
			var result2 = stmt.trace;
			result2.children += codeFragmentProvider.create('''«inferenceResult.ctype» «stmt.name»;''');
			val funCall = generateFunCallStmt(stmt.name, inferenceResult, initialization);
			result2.children += funCall;
			if(funCall !== null) {
				result = result2;	
			}
		}

		// DEFAULT case
		if (result === null) {
			// if we're in here none of the special cases above matched here. Let's use the default case.
			if (stmt.initialization !== null) {
				result = codeFragmentProvider.
					create('''«inferenceResult.ctype» «stmt.name» = «stmt.initialization.code.noTerminator»;''');
			} else if (type instanceof StructureType) {
				result = codeFragmentProvider.create(
				'''
					«inferenceResult.ctype» «stmt.name»;
					memset((void *) &«stmt.name», 0, sizeof(«inferenceResult.ctype»));
				''');
			} else if (type instanceof PrimitiveType) {
				result = codeFragmentProvider.create('''«inferenceResult.ctype» «stmt.name» = 0;''');
			} else {
				result = codeFragmentProvider.
					create('''«inferenceResult.ctype» «stmt.name»; // WARNING: unsupported initialization''');
			}
		}
		return result;
	}

	@Traced dispatch def IGeneratorNode code(IfStatement stmt) {
		'''
			if(«stmt.condition.code.noTerminator»)
			«stmt.then.code»
			«FOR elif : stmt.elseIf»
				else if(«elif.condition.code.noTerminator»)
				«elif.then.code»
			«ENDFOR»
			«IF stmt.^else !== null»
				else
				«stmt.^else.code»
			«ENDIF»
		'''
	}

	@Traced dispatch def IGeneratorNode code(ThrowExceptionStatement stmt) {
		if (ModelUtils.isInTryCatchFinally(stmt)) {
			'''
				// THROW «stmt.exceptionType.name»
				exception = «codeFragmentProvider.create('''«stmt.exceptionType.baseName»''').addHeader('MitaExceptions.h', true)»;
				break;
			'''
		} else {
			'''
				// THROW «stmt.exceptionType.name»
				return «codeFragmentProvider.create('''«stmt.exceptionType.baseName»''').addHeader('MitaExceptions.h', true)»;
			'''
		}
	}

	@Traced dispatch def IGeneratorNode code(TryStatement stmt) {
		val bool = codeFragmentProvider.create('''bool''').addHeader('stdbool.h', true);
		val runOnce = '''_runOnce«stmt.hashCode»'''
		'''
			// TRY
			returnFromWithinTryCatch = false;
			for(«bool» «runOnce» = true; «runOnce»; «runOnce» = false)
			«stmt.^try.code»
			«FOR idx_catchStmt : stmt.catchStatements.indexed»
				// CATCH «idx_catchStmt.value.exceptionType.name»
				«IF idx_catchStmt.key > 0»else «ENDIF»if(exception «IF idx_catchStmt.value.exceptionType.name == 'Exception'»!= NO_EXCEPTION«ELSE»== «idx_catchStmt.value.exceptionType.baseName»«ENDIF»)
				{
					exception = NO_EXCEPTION;
«««If we are in try OR in catch we need to only exit the try/catch block, since we also need to execute finally. Therefore we generate a for loop as well
					for(bool «runOnce» = true; «runOnce»; «runOnce» = false)
					«idx_catchStmt.value.body.code»
				}
			«ENDFOR»
			«IF stmt.^finally !== null»
				// FINALLY
				for(bool «runOnce» = true; «runOnce»; «runOnce» = false)
				«stmt.^finally.code»
			«ENDIF»
««« If we returned in a try-, catch- or finally-block, we only exited that block. Furthermore, if we didn't catch an exception, we need to fall through.
			if(returnFromWithinTryCatch || exception != NO_EXCEPTION) {
««« We might be in a nested try/etc.. In that case we should only break, and continue handling exceptions and executing finally.
			«IF ModelUtils.isInTryCatchFinally(stmt.eContainer)»
				break;
			«ELSE»
				return exception;
			«ENDIF»
			}
		'''
	}

	@Traced dispatch def IGeneratorNode code(WhileStatement stmt) {
		'''
			while(«stmt.condition.code.noTerminator»)
			«stmt.body.code»
			«IF ModelUtils.isInTryCatchFinally(stmt)»
			if(exception != NO_EXCEPTION) break;
			«ENDIF»
		'''
	}

	@Traced dispatch def IGeneratorNode code(ForStatement stmt) {
		val condition = stmt.condition.code.noTerminator;
		'''
			for(«FOR x : stmt.loopVariables SEPARATOR ' ,'»«x.code.noTerminator»«ENDFOR»; «condition»; «FOR x : stmt.postLoopStatements SEPARATOR ' ,'»«x.code.noTerminator»«ENDFOR»)
			«stmt.body.code»
			«IF ModelUtils.isInTryCatchFinally(stmt)»
			if(exception != NO_EXCEPTION) break;
			«ENDIF»
		'''
	}

	@Traced dispatch def IGeneratorNode code(ForEachStatement stmt) {
		'''
			// ERROR: for-each statements are not supported yet
		'''
	}

	@Traced dispatch def IGeneratorNode code(DoWhileStatement stmt) {
		'''
			do 
			«stmt.body.code»
			while(«stmt.condition.code.noTerminator»);
			«IF ModelUtils.isInTryCatchFinally(stmt)»
			if(exception != NO_EXCEPTION) break;
			«ENDIF»
		'''
	}

	@Traced dispatch def IGeneratorNode code(ConditionalExpression it) {
		'''«condition.code.noTerminator» ? «trueCase.code.noTerminator» : «falseCase.code»'''
	}

	@Traced dispatch def IGeneratorNode code(ProgramBlock stmt) {
		// TODO: analyze content and check for sensor access
		'''
			{
				«FOR x : stmt.content SEPARATOR '\n'»
					«x.code»
				«ENDFOR»
			}
		'''
	}

	@Traced dispatch def IGeneratorNode code(FunctionDefinition stmt) {
		'''
			«stmt.header.noTerminator»
			{
			«stmt.body.code.noBraces»
				return exception;
			}
		'''
	}
	
	@Traced dispatch def IGeneratorNode code(SourceCodeComment stmt) {
		'''
			/*
			«stmt.content»
			*/
		'''
	}

	@Traced dispatch def IGeneratorNode code(AbstractStatement stmt) {
		// fallback ... we haven't implemented the statement yet
		'''Unsuported statement: «stmt»'''
	}
		
	@Traced dispatch def IGeneratorNode code(WhereIsStatement stmt) {
		'''
		switch(«stmt.matchElement.code».tag) {
			«FOR isCase: stmt.isCases» 
			«isCase.code»
			«ENDFOR»
		}
		'''
	}
	@Traced dispatch def IGeneratorNode code(IsTypeMatchCase stmt) {
		val varType = stmt.productType;
		'''
		case «varType.enumName»: {
			«stmt.body.code.noBraces»
			break;
		}
		'''
	}
	
	@Traced dispatch def IGeneratorNode code(IsAssignmentCase stmt) {
		val varTypeSpec = stmt.assignmentVariable.typeSpecifier;
		val varType = varTypeSpec.type as SumAlternative;
		val where = stmt.eContainer as WhereIsStatement;
		'''
		case «varType.enumName»: {
			«varTypeSpec.ctype» «stmt.assignmentVariable.name» = «where.matchElement.code».data.«varType.structName»;
			«stmt.body.code.noBraces»
			break;
		}
		'''
	}
	
	@Traced dispatch def IGeneratorNode code(IsDeconstructionCase stmt) {
		val varType = stmt.productType;
		'''
		case «varType.enumName»: {
			«FOR deconstructor: stmt.deconstructors»
			«deconstructor.code»
			«ENDFOR»
			«stmt.body.code.noBraces»
			break;
		}
		'''
	}
	
	@Traced dispatch def IGeneratorNode code(IsOtherCase stmt) {
		'''
		default: {
			«stmt.body.code.noBraces»
			break;
		}
		'''
	}
	
	def Function<Integer, String> accessor(SumAlternative productType, Parameter preferred, String prefix, String suffix) {
		[idx | 
			if(preferred !== null) {
				'''«prefix»«preferred.name»«suffix»'''	
			}
			else if(productType instanceof AnonymousProductType) {
				if(productType.typeSpecifiers.length > 1) {
					'''«prefix»_«idx»«suffix»''';	
				}
				// if we have only one type, we are an alias for another type
				else {
					// check if that is a struct
					val realType = productType.typeSpecifiers.head.type;
					if(realType instanceof StructureType) {
						'''«prefix»«realType.parameters.get(idx).baseName»«suffix»''';	
					}
					else {
						'''''';
					}
				}
			}
			else if(productType instanceof NamedProductType) {
				'''«prefix»«productType.parameters.get(idx).baseName»«suffix»''';
			}
			else {
				'''ERROR: NEITHER ANONYMOUS NOR NAMED, YOU MUST NEVER GET HERE''';
			} ]
	}
	
	@Traced dispatch def IGeneratorNode code(IsDeconstructor stmt) {
		val varTypeSpec = stmt.inferType;
		val isDeconstructionCase = stmt.eContainer as IsDeconstructionCase;
		val isDeconstructionCaseType = isDeconstructionCase.productType;
		val where = isDeconstructionCase.eContainer as WhereIsStatement;
		val altAccessor = isDeconstructionCaseType.structName;
		val idx = isDeconstructionCase.deconstructors.indexOf(stmt);
		val productType = isDeconstructionCase.productType;
		val member = accessor(productType, stmt.productMember, ".", "").apply(idx);
		'''«varTypeSpec.ctype» «stmt.name» = «where.matchElement.code».data.«altAccessor»«member»;'''
	}
	
	@Traced dispatch def IGeneratorNode code(LoopBreakerStatement stmt) {
		'''
		if(«stmt.condition.code.noTerminator»)
		{
			// loop condition still holds: continue the loop
		}
		else
		{
			// loop condition no longer holds: break the loop
			break;
		}
		'''
	}

	@Traced dispatch def header(FunctionDefinition definition) {
		val resultType = definition.inferType;
		'''«exceptionGenerator.exceptionType» «definition.baseName»(«resultType.ctype»* _result«IF !definition.parameters.empty», «ENDIF»«FOR x : definition.parameters SEPARATOR ', '»«x.inferType.ctype» «x.name»«ENDFOR»);'''
	}
	
	dispatch def IGeneratorNode header(StructureType definition) {
		return structureTypeCode(definition);
	}
	
	def IGeneratorNode structureTypeCode(StructureType definition) {
		return structureTypeCodeDecl(definition, definition.parameters, definition.baseName);
	}
	
	def IGeneratorNode structureTypeCodeDecl(EObject obj, List<Parameter> parameters, String typeName) {
		return structureTypeCodeReal(obj, parameters.map[new Pair(it.inferType.ctype, it.baseName)], typeName);
	
	}
	@Traced def IGeneratorNode structureTypeCodeReal(EObject obj, List<Pair<CodeFragment, String>> typesAndNames, String typeName) {
		'''
		typedef struct {
			«FOR field : typesAndNames»
			«field.key» «field.value»;
			«ENDFOR»
		} «typeName»;
		'''
	} 
	
	@Traced dispatch def IGeneratorNode header(SumType definition) {
		val nonSingletonAlternatives = definition.alternatives.filter[!(it instanceof Singleton)];
		val hasOneMember = [ SumAlternative alt | 
			if(alt instanceof AnonymousProductType) {
				return alt.typeSpecifiers.length == 1;
			} else {
				return false;
			}
		]
		
		'''
		«FOR alternative: definition.alternatives.filter(NamedProductType)»
		«structureTypeCodeDecl(alternative, alternative.parameters, alternative.structType)»
		«ENDFOR»
		
		««« anonymous alternatives get tuple-like accessors (_1, _2, ...)
		«FOR alternative: definition.alternatives.filter(AnonymousProductType)»
		««« If we have only one typeSpecifier, we shorten to an alias, so we don't create a struct here 	
		«IF alternative.typeSpecifiers.length > 1»
		«structureTypeCodeReal(alternative, alternative.typeSpecifiers.indexed.map[new Pair(it.value.inferType.ctype, '''_«it.key»''')].toList, alternative.structType)»
		«ENDIF»		
		«ENDFOR»
		
		typedef enum {
			«FOR alternative: definition.alternatives SEPARATOR(",")»
			«alternative.enumName»
			«ENDFOR»
		} «definition.enumName»;
		
		typedef struct {
			«definition.enumName» tag;
			union Data {
				«FOR alternative: nonSingletonAlternatives»«IF hasOneMember.apply(alternative)»«(alternative as AnonymousProductType).typeSpecifiers.head.ctype»«ELSE»«alternative.structType»«ENDIF» «alternative.structName»;
			«ENDFOR»
			} data;
		} «definition.structName»;
		'''
	}

	@Traced dispatch def header(EnumerationType definition) {
		'''
			typedef enum {
				«FOR item : definition.enumerator SEPARATOR ',\n'»«item.baseName»«ENDFOR»
			} «definition.baseName»;
		'''
	}
	
	@Traced def generateNativeFunctionCallChecked(NativeFunctionDefinition op, IGeneratorNode firstArg, ArgumentExpression args) {
		val call = codeFragmentProvider
			.create(generateFunctionCall(op, firstArg, args) as CompositeGeneratorNode)
			.addHeader(op.header, true);
		return '''«call»''';
	}
	
	@Traced def generateNativeFunctionCallUnchecked(NativeFunctionDefinition op, ArgumentExpression args) {
		val call = codeFragmentProvider
			.create('''«op.name»(«FOR arg : ModelUtils.getSortedArguments(op.parameters, args.arguments) SEPARATOR ', '»«arg.value.code.noTerminator»«ENDFOR»)''')
			.addHeader(op.header, true);
		return '''«call»'''
	}
	
	@Traced def generateFunctionCall(Operation op, IGeneratorNode firstArg, ArgumentExpression args) {
		'''
		exception = «op.baseName»(«IF firstArg !== null»«firstArg.noTerminator»«IF !args.arguments.empty», «ENDIF»«ENDIF»«FOR arg : ModelUtils.getSortedArguments(op.parameters, args.arguments) SEPARATOR ', '»«arg.value.code.noTerminator»«ENDFOR»);
		«generateExceptionHandler(args, 'exception')»'''
	}

	private def inferType(EObject expr) {
		return ModelUtils.toSpecifier(typeInferrer.infer(expr));
	}

	private def getCtype(TypeSpecifier type) {
		if(type === null) codeFragmentProvider.create('''void*''') else typeGenerator.code(type);
	}

}
