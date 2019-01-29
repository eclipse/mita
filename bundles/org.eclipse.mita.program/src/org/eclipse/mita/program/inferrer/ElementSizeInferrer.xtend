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

package org.eclipse.mita.program.inferrer

import com.google.inject.Inject
import java.util.LinkedList
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.util.EcoreUtil.UsageCrossReferencer
import org.eclipse.mita.base.expressions.ArrayAccessExpression
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.expressions.ValueRange
import org.eclipse.mita.base.types.AnonymousProductType
import org.eclipse.mita.base.types.ComplexType
import org.eclipse.mita.base.types.EnumerationType
import org.eclipse.mita.base.types.ExceptionTypeDeclaration
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.types.NamedProductType
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.PrimitiveType
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.SumType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.base.util.PreventRecursion
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.SystemResourceAlias
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.resource.PluginResourceLoader
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.mita.base.typesystem.types.NumericType
import static extension org.eclipse.mita.base.types.TypesUtil.isGeneratedType

/**
 * Hierarchically infers the size of a data element.
 */
class ElementSizeInferrer {

	@Inject
	protected PluginResourceLoader loader;


	def ElementSizeInferenceResult infer(EObject obj) {
		return obj.doInfer;
	}
	
	private static class Combination extends ElementSizeInferrer {
		final ElementSizeInferrer i1;
		final ElementSizeInferrer i2;
		new(ElementSizeInferrer i1, ElementSizeInferrer i2) {
			super();
			this.i1 = i1;
			this.i2 = i2;
		}
		
		override infer(EObject obj) {
			i1.infer(obj).orElse([| i2.infer(obj)]);
		}
	}
	
	static def ElementSizeInferrer orElse(ElementSizeInferrer i1, ElementSizeInferrer i2) {
		if(i1 !== null && i2 !== null) {
			return new Combination(i1, i2);
		}
		else {
			return i1?:i2;
		}
	}

	protected def dispatch ElementSizeInferenceResult doInfer(FunctionDefinition obj) {
		return PreventRecursion.preventRecursion(obj, [
			val allReturnSizes = obj.eAllContents.filter(ReturnStatement).map[x | x.infer ].toList();
			var result = if(allReturnSizes.empty) {
				obj.inferFromType
			} else if(allReturnSizes.size == 1) {
				allReturnSizes.head;
			} else {
				val invalidResults = allReturnSizes.filter(InvalidElementSizeInferenceResult);
				if(!invalidResults.isEmpty) {
					invalidResults.head;
				} else {
					newValidResult(obj, allReturnSizes.filter(ValidElementSizeInferenceResult).map[x | x.elementCount ].max);				
				}
			}
			
			return result
		], [|
			return newInvalidResult(obj, '''Function "«obj.name»" is recursive. Cannot infer size.''')
		]);
		
		
		
	}
	
	protected def dispatch ElementSizeInferenceResult doInfer(ArrayAccessExpression obj) {
		val accessor = obj.arraySelector;
		if(accessor instanceof ValueRange) {
			val maxResult = obj.owner.infer;
			if(maxResult instanceof ValidElementSizeInferenceResult) {
				var elementCount = maxResult.elementCount;
				
				if(accessor.lowerBound !== null) {
					val lowerBound = StaticValueInferrer.infer(accessor.lowerBound, [x|]);
					elementCount -= (lowerBound as Integer)?:0;
				}	
				if(accessor.upperBound !== null) {
					val upperBound = StaticValueInferrer.infer(accessor.upperBound, [x|]);
					elementCount -= maxResult.elementCount - ((upperBound as Integer)?:0);
				}
				
				val result = new ValidElementSizeInferenceResult(maxResult.root, maxResult.typeOf, elementCount);
				result.children += maxResult.children;
				return result;
			}
			return maxResult;
		}
		else {
			return obj.inferFromType
		}
	}
	
	protected def dispatch ElementSizeInferenceResult doInfer(ElementReferenceExpression obj) {
		val inferredSize = obj.inferFromType;
		if (inferredSize instanceof ValidElementSizeInferenceResult) {
			return inferredSize;
		}
		return obj.reference.infer;
	}

	protected def dispatch ElementSizeInferenceResult doInfer(ReturnStatement obj) {
		if(obj.value === null) {
			return newInvalidResult(obj, "Return statements without values do not have a size");
		} else {
			return obj.value.infer;
		}
	}
	
	protected def dispatch ElementSizeInferenceResult doInfer(NewInstanceExpression obj) {
		return obj.inferFromType;
	}
	

	protected def dispatch ElementSizeInferenceResult doInfer(VariableDeclaration variable) {
		val type = BaseUtils.getType(variable);
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
		if(initialization === null) {
			variable.inferFromType(type);
		} else {
			return initialization.infer;
		}
	}
	protected def dispatch ElementSizeInferenceResult doInfer(PrimitiveValueExpression obj) {
		return obj.value.infer;
	}
	
	protected def dispatch ElementSizeInferenceResult doInfer(EObject obj) {
		// fallback: try and infer based on the type of the expression
		return obj.inferFromType;
	}
		
	protected def dispatch ElementSizeInferenceResult doInfer(Void obj) {
		return newInvalidResult(null, "Unable to infer size from nothing");
	}
	
	protected def ElementSizeInferenceResult inferFromType(Void type) {
		return newInvalidResult(null, "Unable to infer size from unknown type");
	}
	
	protected def ElementSizeInferenceResult inferFromType(EObject obj) {
		val typeInf = BaseUtils.getType(obj);
		return obj.inferFromType(typeInf);
	}
		

	protected def ElementSizeInferenceResult inferFromType(EObject obj, AbstractType typ) {
		val type = typ.origin;
		// this expression has an immediate value (akin to the StaticValueInferrer)
		if (typ instanceof NumericType || typ.name == "Exception") {
			// it's a primitive type
			return new ValidElementSizeInferenceResult(obj, typ, 1);
		} else if (typ.isGeneratedType) {
			// it's a generated type, so we must load the inferrer
			var ElementSizeInferrer inferrer = null;
			
			// if its a platform component, the component specifies its own inferrer
			val instance = if(obj instanceof ElementReferenceExpression) {
				if(obj.isOperationCall && obj.arguments.size > 0) {
					obj.arguments.head.value; 
				}
			}
			if(instance !== null) {
				if(instance instanceof ElementReferenceExpression) {
					val resourceRef = instance.arguments.head.value;
					if(resourceRef instanceof ElementReferenceExpression) {
						var resourceSetup = resourceRef.reference;
						var Object loadedInferrer = null;
						if(resourceSetup instanceof SystemResourceAlias) {
							resourceSetup = resourceSetup.delegate;
						}
						if(resourceSetup instanceof SystemResourceSetup) {
							val resource = resourceSetup.type;
							loadedInferrer = loader.loadFromPlugin(resource.eResource, resource.sizeInferrer);	
						}
						else if(resourceSetup instanceof AbstractSystemResource) {
							loadedInferrer = loader.loadFromPlugin(resourceSetup.eResource, resourceSetup.sizeInferrer);	
						}
						// we're done loading, let's see if we actually loaded an ESI
						if(loadedInferrer instanceof ElementSizeInferrer) {
							inferrer = loadedInferrer;
						}
						// if we got something else we should warn about this. We could either throw an exception or try to recover by deferring to the default inferrer, but log a warning.
						else if(loadedInferrer !== null) {
							println('''[WARNING] Expected an instance of ElementSizeInferrer, got: «loadedInferrer.class.simpleName»''')
						}
					}
				}
			}
			
			val loadedTypeInferrer = loader.loadFromPlugin(obj.eResource, typ.userData.get("sizeInferrer"));
			
			if(loadedTypeInferrer instanceof ElementSizeInferrer) {			
				inferrer = inferrer.orElse(loadedTypeInferrer);	
			}
			
			val finalInferrer = inferrer;
			if (finalInferrer === null) {
				return new InvalidElementSizeInferenceResult(obj, typ, "Type has no size inferrer");
			} else {
				
				return PreventRecursion.preventRecursion(obj, 
				[|
					return finalInferrer.infer(obj);
				], [|
					return newInvalidResult(obj, '''Cannot infer size of "«obj.class.simpleName»" of type "«type»".''')
				])
			}
		} else if (type instanceof StructureType) {
			// it's a struct, let's build our children, but mark the type first
			return PreventRecursion.preventRecursion(type, [
				val result = new ValidElementSizeInferenceResult(obj, typ, 1);
				result.children.addAll(type.parameters.map[x|x.infer]);
				return result;
			], [|
				return newInvalidResult(obj, '''Type "«type.name»" is recursive. Cannot infer size.''')
			]);
			
		} else if (type instanceof SumType) {
			return PreventRecursion.preventRecursion(type, [
				val childs = type.alternatives.map[it.infer];
				val result = if(childs.filter(InvalidElementSizeInferenceResult).empty) {
					 new ValidElementSizeInferenceResult(obj, typ, 1);
				} else {
					new InvalidElementSizeInferenceResult(obj, typ, '''Cannot infer size of ""«obj.class.simpleName»" of type"«type»".''');
				}
				
				val maxChild = childs.filter(ValidElementSizeInferenceResult).maxBy[it.byteCount];
				val invalidChilds = childs.filter(InvalidElementSizeInferenceResult);
				
				result.children.add(maxChild);
				result.children += invalidChilds;
					
				return result;
			], [|
				return newInvalidResult(obj, '''Type "«type.name»" is recursive. Cannot infer size.''')
			]);
			
			
			
		} else if (type instanceof NamedProductType) {
			// it's a struct, let's build our children, but mark the type first
			return PreventRecursion.preventRecursion(type, [
				val childs = type.parameters.map[x|x.infer];
				val result = new ValidElementSizeInferenceResult(obj, typ, 1);
				result.children.addAll(childs);
				
				return result;
			], [|
				return newInvalidResult(obj, '''Type "«type.name»" is recursive. Cannot infer size.''')
			]);
			
			
			
		} else if (type instanceof AnonymousProductType) {
			// it's a struct, let's build our children, but mark the type first
			return PreventRecursion.preventRecursion(type, [
				val childs = type.typeSpecifiers.map[x|inferFromType(obj, BaseUtils.getType(x))];
				val result = new ValidElementSizeInferenceResult(obj, typ, 1);
				result.children.addAll(childs);
				
				return result;
			], [|
				return newInvalidResult(obj, '''Type "«type.name»" is recursive. Cannot infer size.''')
			]);
			
		}	else if (type instanceof ComplexType) {
			// it's a struct, let's build our children, but mark the type first
			return PreventRecursion.preventRecursion(type, [
				val result = new ValidElementSizeInferenceResult(obj, typ, 1);
				result.children.addAll(type.features.map[x|x.infer]);

				return result;
			], [|
				return newInvalidResult(obj, '''Type "«type.name»" is recursive. Cannot infer size.''')
			]);
			
			
			
		} else if (type === null) {
			// if type is null we have different problems than size inference
			return newValidResult(obj, 0)
		}
		return newInvalidResult(obj, "Unable to infer size from type " + type.toString);
	}
	
	/**
	 * Produces a valid size inference of the root object. This method assumes that the type
	 * we're reporting a multiple of (size parameter) is the result of typeInferer.infer(root). 
	 */
	protected def newValidResult(EObject root, int size) {
		val type = BaseUtils.getType(root);
		return new ValidElementSizeInferenceResult(root, type, size);
	}
	
	/**
	 * Produces an invalid size inference of the root object. This method assumes that the type
	 * we're reporting a multiple of (size parameter) is the result of typeInferer.infer(root). 
	 */
	protected def newInvalidResult(EObject root, String message) {
		val type = BaseUtils.getType(root);
		return new InvalidElementSizeInferenceResult(root, type, message);
	}
	
}

/**
 * The inference result of the ElementSizeInferrer
 */
abstract class ElementSizeInferenceResult {
	val EObject root;
	val AbstractType typeOf;
	val List<ElementSizeInferenceResult> children;
	
	def ElementSizeInferenceResult orElse(ElementSizeInferenceResult esir){
		return orElse([| esir]);
	}
	abstract def ElementSizeInferenceResult orElse(() => ElementSizeInferenceResult esirProvider);
	
	/**
	 * Creates a new valid inference result for an element, its type and the
	 * required element count.
	 */
	protected new(EObject root, AbstractType typeOf) {
		this.root = root;
		this.typeOf = typeOf;
		this.children = new LinkedList<ElementSizeInferenceResult>();
	}
	
	/**
	 * Checks if this size inference and its children are valid/complete.
	 */
	def boolean isValid() {
		return invalidSelfOrChildren.empty;
	}
	
	/**
	 * Returns true if this particular result node is valid.
	 */
	abstract def boolean isSelfValid();
	
	/**
	 * Returns a list of invalid/incomplete inference nodes which can be used for validation
	 * and user feedback.
	 */
	def Iterable<InvalidElementSizeInferenceResult> getInvalidSelfOrChildren() {
		return (if(isSelfValid) #[] else #[this as InvalidElementSizeInferenceResult]) + children.map[x | x.invalidSelfOrChildren ].flatten;
	}
	
	/**
	 * Returns a list of valid/complete inference nodes.
	 */
	def Iterable<ValidElementSizeInferenceResult> getValidSelfOrChildren() {
		return (if(isSelfValid) #[this as ValidElementSizeInferenceResult] else #[]) + children.map[x | x.validSelfOrChildren ].flatten;
	}
	
	/**
	 * The root element this size inference was made from.
	 */
	def EObject getRoot() {
		return root;
	}
	
	/**
	 * The data type we require elements of.
	 */
	def AbstractType getTypeOf() {
		return typeOf;
	}
	
	/**
	 * Any children we require as part of the type (i.e. through type parameters or struct members).
	 */
	def List<ElementSizeInferenceResult> getChildren() {
		return children;
	}
		
	override toString() {
		var result = if(typeOf instanceof PresentTypeSpecifier) {
			typeOf.type.name;
		} else {
			""
		}
		result += ' {' + children.map[x | x.toString ].join(', ') + '}';
		return result;
	}
	
}

class ValidElementSizeInferenceResult extends ElementSizeInferenceResult {
	
	val int elementCount;
	
	new(EObject root, AbstractType typeOf, int elementCount) {
		super(root, typeOf);
		this.elementCount = elementCount;
	}
	
	/**
	 * The number of elements of this type we require.
	 */
	def int getElementCount() {
		return elementCount;
	}
	
	override isSelfValid() {
		return true;
	}
		
	override toString() {
		var result = typeOf?.toString;
		result += '::' + elementCount;
		if(!children.empty) {
			result += 'of{' + children.map[x | x.toString ].join(', ') + '}';			
		}
		return result;
	}
	
	def Integer getByteCount() {
		val type = if(typeOf instanceof PresentTypeSpecifier) { 
			(typeOf as PresentTypeSpecifier).type;
		}
		val ownSize = (
			if(type instanceof EnumerationType) {
				// enums are uint16
				elementCount * 2;
			}
			else if(type instanceof PrimitiveType) {
				elementCount * switch (type.name) {
					case "int64": {
						4;
					}
					case "uint64": {
						4;
					}
					case "int32": {
						4;
					}
					case "uint32": {
						4;
					}
					case "int16": {
						2;
					}
					case "uint16": {
						2;
					}
					case "int8": {
						1;
					}
					case "uint8": {
						1;
					}
					case "float": {
						2;
					}
					case "double": {
						4;
					}
					case "long double": {
						8;
					}
					case "bool": {
						1;
					}
					default: {
						throw new Exception("Unknown type: " + type.name);
					}
				}
			} 
			else if(type instanceof StructureType) {
				0;
			}
			else if(type instanceof SumType) {
				1;
			}
			else {
				0;
			}
		)
		ownSize + elementCount * children
			.filter[x | x instanceof ValidElementSizeInferenceResult]
			.map[x | (x as ValidElementSizeInferenceResult).byteCount]
			.fold(0, [x, y | x + y]);
	}
	
	override orElse(() => ElementSizeInferenceResult esirProvider) {
		return this;
	}
	
}

class InvalidElementSizeInferenceResult extends ElementSizeInferenceResult {
	
	val String message;
	
	new(EObject root, AbstractType typeOf, String message) {
		super(root, typeOf);
		this.message = message;
	}
	
	def String getMessage() {
		return message;
	}
	
	override isSelfValid() {
		return false;
	}
	
	override toString() {
		return "INVALID:" + message + "@" + super.toString();
	}
	
	override orElse(() => ElementSizeInferenceResult esirProvider) {
		var esir = esirProvider?.apply();
		if(esir === null) {
			return this;
		}
		if(esir instanceof InvalidElementSizeInferenceResult) {
			esir = new InvalidElementSizeInferenceResult(esir.root, esir.typeOf, message + "\n" + esir.message);
		}
		return esir;
	}
	
}
