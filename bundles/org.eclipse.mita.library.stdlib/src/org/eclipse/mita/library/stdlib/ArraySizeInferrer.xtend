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

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.util.EcoreUtil.UsageCrossReferencer
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.expressions.ValueRange
import org.eclipse.mita.base.expressions.util.ExpressionUtils
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.typesystem.ITypeSystem
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.AbstractLoopStatement
import org.eclipse.mita.program.ArrayLiteral
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.inferrer.ElementSizeInferenceResult
import org.eclipse.mita.program.inferrer.ElementSizeInferrer
import org.eclipse.mita.program.inferrer.InvalidElementSizeInferenceResult
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.inferrer.ValidElementSizeInferenceResult
import org.eclipse.xtext.EcoreUtil2

import static extension org.eclipse.mita.base.types.TypesUtil.ignoreCoercions
import org.eclipse.mita.base.expressions.ArrayAccessExpression
import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import org.eclipse.mita.program.EventHandlerDeclaration

class ArraySizeInferrer extends ElementSizeInferrer {
	
	@Inject
    protected ITypeSystem registry;
	
	protected def dispatch ElementSizeInferenceResult isolatedDoInfer(ElementReferenceExpression expr) {
		return expr?.infer;
	}
	
	protected def dispatch ElementSizeInferenceResult isolatedDoInfer(EObject expr) {
		newInvalidResult(expr, "Cannot infer length");
	}
	
	protected def dispatch ElementSizeInferenceResult isolatedDoInfer(ArrayAccessExpression expr) {
		val arraySelector = expr.arraySelector.ignoreCoercions?.castOrNull(ValueRange);
		if(arraySelector === null) {
			return _isolatedDoInfer(expr as EObject);
		}
		val ownerSize = expr.owner?.isolatedDoInfer?.castOrNull(ValidElementSizeInferenceResult);
		val lowerBound = StaticValueInferrer.infer(arraySelector.lowerBound, [])?.castOrNull(Long) ?: (0L);
		val upperBound = StaticValueInferrer.infer(arraySelector.upperBound, [])?.castOrNull(Long) ?: (if(ownerSize !== null) ownerSize.elementCount as Long);
		if(upperBound === null) {
			return _isolatedDoInfer(expr as EObject);
		}
		val result = newValidResult(expr, upperBound - lowerBound);
		result.children += ownerSize.children;
		
		return result;
	}
	
	protected def dispatch ElementSizeInferenceResult isolatedDoInfer(ArrayLiteral expression) {
		newValidResult(expression, expression.values.length);		
	}
	
	protected def dispatch ElementSizeInferenceResult isolatedDoInfer(PrimitiveValueExpression expression) {
		val value = expression.value;
		if(value instanceof ArrayLiteral) {
			value.isolatedDoInfer;
		} else {
			newInvalidResult(expression, '''Cannot infer «BaseUtils.getType(expression)?.name ?: "array"» length of «value»''');
		}
	}
	
	protected def inferFixedSize(NewInstanceExpression initialization) {
		val rawSizeValue = ExpressionUtils.getArgumentValue(initialization.reference as Operation, initialization, 'size');
		val staticSizeValue = StaticValueInferrer.infer(rawSizeValue, [x |]);
		return if(staticSizeValue instanceof Long) {
			newValidResult(initialization, staticSizeValue);
		} else {
			newInvalidResult(initialization, "No explicit maximum size was given");
		}
	}
	
	protected dispatch override ElementSizeInferenceResult doInfer(VariableDeclaration variable, AbstractType type) {
		/*
		 * Find initial size
		 */
		val variableRoot = EcoreUtil2.getContainerOfType(variable, Program);
		val referencesToVariable = UsageCrossReferencer.find(variable, variableRoot).map[e | e.EObject ];
		val initialization = variable.initialization ?: (
			referencesToVariable
				.map[it.eContainer]
				.filter(AssignmentExpression)
				.filter[ae |
					val left = ae.varRef; 
					left instanceof ElementReferenceExpression && (left as ElementReferenceExpression).reference === variable 
				]
				.map[it.expression]
				.head
		)
		var arrayHasFixedSize = false;
		val initialLength = if(initialization !== null) {
			if(initialization instanceof NewInstanceExpression) {
				arrayHasFixedSize = true;
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
		]
		.filterNull;
		
		/*
		 * Check if we can infer the length across all modifications
		 */
		for(expr : modifyingExpressions) {
			/*
			 * First, let's see if we can infer the array length after the modification.
			 */
			var allowedInLoop = arrayHasFixedSize;
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
			}
			
			/*
			 * Second, see if the modification happens in a loop. In that case we don't bother with trying to infer the length.
			 * Because of block scoping we just have to find a loop container of the modifyingExpression and then make sure that
			 * the loop container and the variable definition are/share a common ancestor.
			 */
			if(!allowedInLoop) {
				val loopContainer = expr.getSharedLoopContainer(variable);
				if(loopContainer !== null) {
					return newInvalidResult(expr, '''Cannot infer «BaseUtils.getType(variable)?.name ?: "array"» length in loops''');
				}	
			}
		}
		
		return newValidResult(variable, length);
	}
	
	override protected dispatch doInfer(NewInstanceExpression obj, AbstractType type) {
		val parentType = BaseUtils.getType(obj.eContainer);
		
		val rawSizeValue = ExpressionUtils.getArgumentValue(obj.reference as Operation, obj, 'size');
		if(rawSizeValue === null) {
			return new InvalidElementSizeInferenceResult(obj, parentType, "size missing");
		} else if(parentType === null) {
			return new InvalidElementSizeInferenceResult(obj, parentType, "parent type unknown");
		} else {
			val staticSizeValue = StaticValueInferrer.infer(rawSizeValue, [x |]);
			val result = if(staticSizeValue === null) {
				newInvalidResult(obj.reference, "Cannot infer static value");
			} else {
				// lets assume that no one constructs arrays bigger than Integer.MAX_VALUE
				new ValidElementSizeInferenceResult(obj, parentType, (staticSizeValue as Long).longValue as int);
			}
			
			/**
			 * TODO: at the moment we don't have array/struct literals. As such the size inference for arrays
			 * is limited to primitive types, because the size of generated types is determined during initialization.
			 */
			val typeOfChildren = (parentType as TypeConstructorType).typeArguments.tail.head;
			result.children.add(obj.inferFromType(typeOfChildren));
			return result;
		}
	}
	
	def protected dispatch doInfer(ArrayLiteral obj, AbstractType type) {
		val parentType = BaseUtils.getType(obj.eContainer);
		
		val typeOfChildren = (parentType as TypeConstructorType).typeArguments.tail.head;
		
		val result = new ValidElementSizeInferenceResult(obj, parentType, obj.values.length);
		 
		if(typeOfChildren.name == StdlibTypeRegistry.arrayTypeQID.lastSegment) {
			result.children.add(infer(obj.values.head));	
		}
		else {
			result.children.add(super.infer(obj.values.head));	
		}
		return result;			
	}
	
	override protected dispatch doInfer(ElementReferenceExpression obj, AbstractType type) {
		val arraySelectors = obj.arraySelector.map[it.ignoreCoercions];
		if(obj.arrayAccess && arraySelectors.head instanceof ValueRange) {
			val valRange = arraySelectors.head as ValueRange;
			
			val parentType = BaseUtils.getType(obj);
			val typeOfChildren = (parentType as TypeConstructorType).typeArguments.tail.head;
			
			val lowerBound = StaticValueInferrer.infer(valRange.lowerBound, [x |]);
			val upperBound = StaticValueInferrer.infer(valRange.upperBound, [x |]);
			if(!(lowerBound instanceof Integer && upperBound instanceof Integer)) {
				return new InvalidElementSizeInferenceResult(obj, parentType, "can not infer size for this range");
			}
			val elCount = (upperBound as Integer) - (lowerBound as Integer) + 1;
			
			val result = new ValidElementSizeInferenceResult(obj, parentType, elCount);
			result.children.add(obj.inferFromType(typeOfChildren));
			return result;
		} else {
			return super._doInfer(obj, type);
		}
	}
	
	/**
	 * Finds a loop ancestor of expr which shares a common ancestor with other.
	 */
	protected static def getSharedLoopContainer(EObject expr, EObject other) {
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