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

package org.eclipse.mita.library.stdlib

import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.util.EcoreUtil.UsageCrossReferencer
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.expressions.StringLiteral
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.AbstractLoopStatement
import org.eclipse.mita.program.InterpolatedStringExpression
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.inferrer.ElementSizeInferenceResult
import org.eclipse.mita.program.inferrer.ElementSizeInferrer
import org.eclipse.mita.program.inferrer.InvalidElementSizeInferenceResult
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.inferrer.ValidElementSizeInferenceResult
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.xtext.EcoreUtil2

class StringSizeInferrer extends ElementSizeInferrer {
	
	protected dispatch def ElementSizeInferenceResult doInfer(StringLiteral expression) {
		expression.inferContainerIfVariableDeclaration[ expression.isolatedDoInfer ]
	}
	
	protected dispatch override ElementSizeInferenceResult doInfer(PrimitiveValueExpression expression) {
		expression.inferContainerIfVariableDeclaration[ expression.isolatedDoInfer ]
	}

	protected dispatch def ElementSizeInferenceResult doInfer(InterpolatedStringExpression expr) {
		expr.inferContainerIfVariableDeclaration[ expr.isolatedDoInfer ]
	}
	
	protected dispatch override ElementSizeInferenceResult doInfer(NewInstanceExpression expr) {
		expr.inferContainerIfVariableDeclaration[ expr.inferFixedSize ]
	}
	
	/**
	 * Computes the maximum length of a string variable.
	 * 
	 * @return the max length of the string or -1 if the length could not be infered.
	 */
	protected dispatch override ElementSizeInferenceResult doInfer(VariableDeclaration variable) {
		/*
		 * Find initial size
		 */
		var stringHasFixedSize = false;
		val initialLength = if(variable.initialization !== null) {
			val initialization = variable.initialization;
			if(initialization instanceof NewInstanceExpression) {
				stringHasFixedSize = true;
				initialization.inferFixedSize();
			} else {
				initialization.isolatedDoInfer();
			}
		} else {
			newInvalidResult(variable, "Cannot infer size of initialization");
		}
		if(initialLength instanceof InvalidElementSizeInferenceResult) {
			return initialLength;
		}
		var length = (initialLength as ValidElementSizeInferenceResult).elementCount;

		/*
		 * Strategy is to find all places where this variable is modified and try to infer the length there.
		 */		
		val variableRoot = EcoreUtil2.getContainerOfType(variable, Program);
		val referencesToVariable = UsageCrossReferencer.find(variable, variableRoot).map[e | e.EObject ];
		val modifyingExpressions = referencesToVariable.map[ref | 
			val refContainer = ref.eContainer;
			
			if(refContainer instanceof AssignmentExpression) {
				if(refContainer.varRef == ref) {
					// we're actually assigning to this reference, thus modifying it
					refContainer					
				} else {
					// the variable reference is just on the right side. No modification happening
					null
				}
			} else if(refContainer instanceof FeatureCall) {
				refContainer
			} else {
				null
			}
		].filterNull;
		
		/*
		 * Check if we can infer the length across all modifications
		 */
		for(expr : modifyingExpressions) {
			/*
			 * First, let's see if we can infer the string length after the modification.
			 */
			var allowedInLoop = stringHasFixedSize;
			if(expr instanceof AssignmentExpression) {
				if(expr.operator == AssignmentOperator.ADD_ASSIGN) {
					val additionLength = expr.expression.infer();
					if(!additionLength.isValid) return additionLength;
					
					length += (additionLength as ValidElementSizeInferenceResult).elementCount;
				} else if(expr.operator == AssignmentOperator.ASSIGN) {
					val additionLength = expr.expression.infer();
					if(!additionLength.isValid) return additionLength;
					
					allowedInLoop = true;
					length = Math.max(length, (additionLength as ValidElementSizeInferenceResult).elementCount);
				} else {
					// can't infer the length due to unknown operator
					return newInvalidResult(expr, '''Cannot infer size when using the «expr.operator.getName()» operator''')
				}
			} else if(expr instanceof FeatureCall) {
				// Feature calls are not yet supported. Abort inference here.
				return newInvalidResult(expr, '''Cannot infer size of feature calls yet''')
			}
			
			/*
			 * Second, see if the modification happens in a loop. In that case we don't bother with trying to infer the length.
			 * Because of block scoping we just have to find a loop container of the modifyingExpression and then make sure that
			 * the loop container and the variable definition are/share a common ancestor.
			 */
			if(!allowedInLoop) {
				val loopContainer = expr.getSharedLoopContainer(variable);
				if(loopContainer !== null) {
					return newInvalidResult(expr, 'Cannot infer string length in loops');
				}	
			}
		}
		
		return newValidResult(variable, length);
	}
	
	protected def dispatch ElementSizeInferenceResult isolatedDoInfer(StringLiteral expression) {
		newValidResult(expression, expression.value.length);		
	}
	
	protected def dispatch ElementSizeInferenceResult isolatedDoInfer(PrimitiveValueExpression expression) {
		val value = expression.value;
		if(value instanceof StringLiteral) {
			value.isolatedDoInfer;
		} else {
			newInvalidResult(expression, "Cannot infer string length of " + value);
		}
	}
	
	protected def dispatch isolatedDoInfer(InterpolatedStringExpression expr) {
		var length = expr.sumTextParts
		
		// sum expression value part
		for(subexpr : expr.content) {
			val type = BaseUtils.getType(subexpr);
			var typeLengthInBytes = switch(type?.name) {
				case 'uint32': 10
				case 'uint16':  5
				case 'uint8':   3
				case 'int32':  11
				case 'int16':   6
				case 'int8':    4
				case 'bool':    1
				// https://stackoverflow.com/a/1934253
				case 'double': StringGenerator.DOUBLE_PRECISION + 1 + 1 + 5 + 1
				case 'float':  StringGenerator.DOUBLE_PRECISION + 1 + 1 + 5 + 1
				case 'string':    {
					val stringSize = super.infer(subexpr);
					if(stringSize instanceof ValidElementSizeInferenceResult) {
						stringSize.elementCount;
					} else {
						// stringSize inference was not valid
						return stringSize;
					}
				}
				default: null
			}
			
			if(typeLengthInBytes === null) {
				return newInvalidResult(subexpr, "Cannot interpolate expressions of type " + type);
			} else {
				length += typeLengthInBytes;
			}
		}

		return newValidResult(expr, length);
	}
	
	protected def dispatch isolatedDoInfer(ElementReferenceExpression expr) {
		return expr?.reference?.infer;
	}
	
	protected def dispatch isolatedDoInfer(EObject expr) {
		newInvalidResult(expr, "Cannot infer string length");
	}
	
	protected def int sumTextParts(InterpolatedStringExpression expr) {
		val texts = StringGenerator.getOriginalTexts(expr)
		if (texts.nullOrEmpty) {
			0
		} else {
			texts.map[x | x.length ].reduce[x1, x2| x1 + x2 ];
		}
	}
	
	
	protected def inferContainerIfVariableDeclaration(EObject obj, (EObject) => ElementSizeInferenceResult alternative) {
		// Special case: we're in an interpolated string, then the variable declaration does not matter
		if(EcoreUtil2.getContainerOfType(obj, InterpolatedStringExpression) !== null) {
			return alternative.apply(obj);
		}
		
		val container = EcoreUtil2.getContainerOfType(obj, VariableDeclaration);
		return if(container !== null) {
			// we must not just infer the size for the new instance in isolation, but also check what's happening to the value afterwards.
			container.infer;
		} else {
			return alternative.apply(obj);
		}
	}
	
	protected def inferFixedSize(NewInstanceExpression initialization) {
		val rawSizeValue = ModelUtils.getArgumentValue(initialization.reference as Operation, initialization, 'size');
		val staticSizeValue = StaticValueInferrer.infer(rawSizeValue, [x |]);
		return if(staticSizeValue instanceof Integer) {
			newValidResult(initialization, staticSizeValue);
		} else {
			newInvalidResult(initialization, "No explicit maximum string size was given");
		}
	}
	
	/**
	 * Finds a loop ancestor of expr which shares a common ancestor with other.
	 */
	private static def getSharedLoopContainer(EObject expr, EObject other) {
		val loopContainer = EcoreUtil2.getContainerOfType(expr, AbstractLoopStatement);
		if(loopContainer !== null) {
			/* We found a loop containing the modifying expression. Let's make sure they share a parent with the variable declaration. */
			val variableContainer = other.eContainer;
			val sharedAncestor = EcoreUtil2.getAllContainers(loopContainer).findFirst[c | c == variableContainer];
			
			if(variableContainer == loopContainer || sharedAncestor !== null) {
				/* We have a found a string manipulation in a loop. We won't bother trying to infer the new string length. */
				return loopContainer;
			}				
		}
		return null;
	}
	
	
}