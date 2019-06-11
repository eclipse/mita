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

import com.google.common.base.Optional
import com.google.inject.Inject
import java.util.HashMap
import java.util.HashSet
import java.util.LinkedList
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.util.EcoreUtil.UsageCrossReferencer
import org.eclipse.mita.base.expressions.ArrayAccessExpression
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.expressions.ValueRange
import org.eclipse.mita.base.types.CoercionExpression
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.TypeReferenceSpecifier
import org.eclipse.mita.base.types.TypeUtils
import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.typesystem.infra.AbstractSizeInferrer
import org.eclipse.mita.base.typesystem.infra.ElementSizeInferrer
import org.eclipse.mita.base.typesystem.infra.MitaBaseResource
import org.eclipse.mita.base.typesystem.infra.NullSizeInferrer
import org.eclipse.mita.base.typesystem.solver.ConstraintSolution
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.base.util.PreventRecursion
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.resource.PluginResourceLoader
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtext.EcoreUtil2

import static extension org.eclipse.mita.base.types.TypeUtils.ignoreCoercions
import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import static extension org.eclipse.mita.base.util.BaseUtils.force
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.xtext.util.Triple
import org.eclipse.xtext.util.Tuples
import org.eclipse.mita.base.typesystem.infra.InferenceContext
import java.util.Map
import org.eclipse.mita.base.types.Operation

/**
 * Hierarchically infers the size of a data element.
 */
class ProgramSizeInferrer extends AbstractSizeInferrer implements ElementSizeInferrer {

	@Inject
	protected PluginResourceLoader loader;
	
	@Accessors 
	ElementSizeInferrer delegate = new NullSizeInferrer();
	
	static def ElementSizeInferrer orElse(ElementSizeInferrer i1, ElementSizeInferrer i2) {
		if(i1 !== null && i2 !== null) {
			return new Combination(i1, i2);
		}
		else {
			return i1?:i2;
		}
	}
		
	override ConstraintSolution inferSizes(ConstraintSolution cs, Resource r) {
		val system = new ConstraintSystem(cs.constraintSystem);
		val sub = new Substitution(cs.solution);
		val toBeInferred = unbindSizes(system, sub, r).force;
		/* All modified types need to have their size inferred.
		 * Size inferrers may only recurse on contained objects, but may otherwise follow references freely.
		 * That means that infer(ElementReferenceExpression r) may not call infer(r.reference), but may look at all other already available information.
		 * This means that sometimes it may not be possible to infer the size for something right now, we are waiting for another size to be inferred.
		 * In that case infer returns its arguments and they are added to the end of the queue.
		 * To prevent endless loops we require that in each full run of the queue there are less objects re-inserted than removed.
		 * For this we keep track of all re-inserted elements and clear this set whenever we didn't reinsert something. 
		 */
		var reinsertionCount = 0;
		while(!toBeInferred.empty && reinsertionCount < toBeInferred.size) {
			val c = toBeInferred.remove(0);
			val toReInsert = startInference(c);
			if(toReInsert.present) {
				toBeInferred.add(toReInsert.get);
				reinsertionCount++;
			}
			else {
				reinsertionCount = 0;
			}
		}
		
		return new ConstraintSolution(system, sub, cs.issues);	
	}
	
	override Iterable<InferenceContext> unbindSize(InferenceContext c) {
		if(TypeUtils.isGeneratedType(c.system, c.type)) {
			val inferrer = getInferrer(c)
			if(inferrer !== null) {
				inferrer.delegate = this;
				return inferrer.unbindSize(c);
			}
		}
		return #[];
	}
	
	def Iterable<InferenceContext> unbindSizes(ConstraintSystem system, Substitution sub, Resource r) {
		return r.contents.flatMap[it.eAllContents.toIterable].flatMap[
			val tv = system.getTypeVariable(it);
			val type = sub.apply(tv);
			val unitsOfWork = unbindSize(new InferenceContext(system, sub, r, it, tv, type));
			return unitsOfWork;
		]
	}
	
	def getInferrer(InferenceContext c) {
		val obj = c.obj;
		val typeInferrerCls = if(TypeUtils.isGeneratedType(c.system, c.type)) {
			c.system.getUserData(c.type, BaseConstraintFactory.SIZE_INFERRER_KEY);
		}
		val typeInferrer = if(typeInferrerCls !== null) { 
			loader.loadFromPlugin(c.r, typeInferrerCls)?.castOrNull(ElementSizeInferrer) => [
				it?.setDelegate(this)]
		}
		
		// all generated elements may supply an inferrer
		// function calls
		val functionInferrerCls = if(obj instanceof ElementReferenceExpression) {
			if(obj.operationCall) {
				val ref = obj.reference;
				if(ref instanceof GeneratedFunctionDefinition) {
					ref.sizeInferrer;
				}
			}
		}
		val functionInferrer = if(functionInferrerCls !== null) { 
			loader.loadFromPlugin(obj.eResource, typeInferrerCls)?.castOrNull(ElementSizeInferrer) => [
				it?.setDelegate(this)
			]
		};
		
//		// system resources
//		val systemResourceInferrerCls = obj.getRelevantSystemResource()?.sizeInferrer;
//		val systemResourceInferrer = if(systemResourceInferrerCls !== null) { loader.loadFromPlugin(obj.eResource, systemResourceInferrerCls) };
		
		return functionInferrer.orElse(typeInferrer)
	}
	
	// only generated types have special needs for size inference for now
	def Optional<InferenceContext> startInference(InferenceContext c) {		
		val inferrer = getInferrer(c);
		
		// the result of the first argument to ?: is null iff the inferrer are null (or the inferrer didn't follow the contract).
		// Then nobody wants to infer anything for this type and we return success.
		// from how this function is called that should never happen, since somebody unbound a type,
		// but its better to reason locally and not introduce a global dependency.
		return inferrer?.infer(c) ?: Optional.absent;
	}
	
	def void inferUnmodifiedFrom(ConstraintSystem system, Substitution sub, EObject target, EObject delegate) {
		sub.add(system.getTypeVariable(target), system.getTypeVariable(delegate));
	}
	
	override Optional<InferenceContext> infer(InferenceContext c) {
		doInfer(c, c.obj);
	}
	
	dispatch def Optional<InferenceContext> doInfer(InferenceContext c, ElementReferenceExpression obj) {
		if(obj.isOperationCall) {
			val fun = obj.reference;
			if(fun instanceof GeneratedFunctionDefinition) {
				val inferrerCls = fun.sizeInferrer;
				val inferrer = loader.loadFromPlugin(c.r, inferrerCls)?.castOrNull(ElementSizeInferrer);
				if(inferrer !== null) { 
					inferrer.delegate = this;
					return inferrer.infer(c);
				}
				else {
					c.sub.add(c.tv, c.type)
					return Optional.absent();
				}
			}
			else if(fun instanceof Operation) {
				inferUnmodifiedFrom(c.system, c.sub, obj, fun.typeSpecifier);
				return Optional.absent();
			}
		}
		inferUnmodifiedFrom(c.system, c.sub, obj, obj.reference);
		return Optional.absent();
	}
	
	dispatch def Optional<InferenceContext> doInfer(InferenceContext c, CoercionExpression obj) {
		inferUnmodifiedFrom(c.system, c.sub, obj, obj.value);
		return Optional.absent();
	}
	
	dispatch def Optional<InferenceContext> doInfer(InferenceContext c, VariableDeclaration variable) {
		val variableRoot = EcoreUtil2.getContainerOfType(variable, Program);
		val referencesToVariable = UsageCrossReferencer.find(variable, variableRoot).map[e | e.EObject ];
		val typeOrigin = (variable.typeSpecifier.castOrNull(PresentTypeSpecifier) ?: variable.initialization) ?: (
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
		if(typeOrigin !== null) {
			inferUnmodifiedFrom(c.system, c.sub, variable, typeOrigin);
		}
		return Optional.absent();
	}
	
	dispatch def Optional<InferenceContext> doInfer(InferenceContext c, PrimitiveValueExpression obj) {
		inferUnmodifiedFrom(c.system, c.sub, obj, obj.value);
		return Optional.absent();
	}
	
	dispatch def Optional<InferenceContext> doInfer(InferenceContext c, ReturnStatement obj) {
		inferUnmodifiedFrom(c.system, c.sub, obj, obj.value);
		return Optional.absent();
	}
	
	dispatch def Optional<InferenceContext> doInfer(InferenceContext c, NewInstanceExpression obj) {
		inferUnmodifiedFrom(c.system, c.sub, obj, obj.type);
		return Optional.absent();
	}
	
	dispatch def Optional<InferenceContext> doInfer(InferenceContext c, EObject obj) {
		return Optional.absent();
	}
	
//	/*
//	 * Walks to referenced system resources.
//	 * Which kinds of ways are there to do this?
//	 * a.b.read()
//	 */
//	
//	dispatch def AbstractSystemResource getRelevantSystemResource(ElementReferenceExpression ref) {
//		
//	}
//
//	dispatch def AbstractSystemResource getRelevantSystemResource(EObject ref) {
//		
//	}
	

		
	dispatch def Optional<InferenceContext> doInfer(InferenceContext c, FunctionDefinition obj) {
		val explicitType = obj.typeSpecifier.castOrNull(PresentTypeSpecifier);
		if(explicitType !== null) {
			inferUnmodifiedFrom(c.system, c.sub, obj, explicitType);
			return Optional.absent();
		}
		
		val returnedTypes = obj.eAllContents.filter(ReturnStatement).map[x | 
			BaseUtils.getType(c.system, c.sub, x);
		].force;
		if(returnedTypes.empty) {
			// can't infer anything if there are no return statements
			return Optional.absent();
		}
		val maxType = max(c.system, c.r, obj, returnedTypes);
		if(maxType.present) {
			c.sub.add(c.system.getTypeVariable(obj), maxType.get);
			return Optional.absent();
		}
		
		return Optional.of(c);
	}
	
	override max(ConstraintSystem system, Resource r, EObject objOrProxy, Iterable<AbstractType> types) {
		val typeInferrer = getInferrer(new InferenceContext(system, Substitution.EMPTY, r, objOrProxy, system.getTypeVariable(objOrProxy), types.head));
		if(typeInferrer !== null) {
			return typeInferrer.max(system, r, objOrProxy, types);
		}
		
		return Optional.of(types.head);
	}
}

@FinalFieldsConstructor
class Combination implements ElementSizeInferrer {
	final ElementSizeInferrer i1;
	final ElementSizeInferrer i2;		
					
	override infer(InferenceContext c) {
		val r1 = i1.infer(c);
		if(r1.present) {
			val r2 = i2.infer(c);
			if(r2.present) {
				// neither can handle this right now. Which pair do we return?
				// In theory both should return the same pair, but this might change.
				return r1;
			}
			else {
				return r2;
			}
		}
		else {
			return r1;
		}
	}
	
	override unbindSize(InferenceContext c) {
		return i1.unbindSize(c).fold(#[], [Iterable<InferenceContext> r1, c1 |
			 r1 + i2.unbindSize(c1);
		])
	}
	
	override setDelegate(ElementSizeInferrer delegate) {
		i1.delegate = delegate;
		i2.delegate = delegate;
	}
	
	override max(ConstraintSystem system, Resource r, EObject objOrProxy, Iterable<AbstractType> types) {
		return i1.max(system, r, objOrProxy, types).or(i2.max(system, r, objOrProxy, types))
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
	
	abstract def ElementSizeInferenceResult replaceRoot(EObject root);
	
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
		var result = if(typeOf instanceof TypeReferenceSpecifier) {
			typeOf.type.name;
		} else {
			""
		}
		result += ' {' + children.map[x | x.toString ].join(', ') + '}';
		return result;
	}
	
}

class ValidElementSizeInferenceResult extends ElementSizeInferenceResult {
	
	val long elementCount;
	
	new(EObject root, AbstractType typeOf, long elementCount) {
		super(root, typeOf);
		this.elementCount = elementCount;
	}
	
	/**
	 * The number of elements of this type we require.
	 */
	def long getElementCount() {
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
		
	override orElse(() => ElementSizeInferenceResult esirProvider) {
		return this;
	}
	
	override replaceRoot(EObject root) {
		val result = new ValidElementSizeInferenceResult(root, this.typeOf, this.elementCount);
		result.children += children;
		return result;
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
	
	override replaceRoot(EObject root) {
		val result = new InvalidElementSizeInferenceResult(root, this.typeOf, this.message);
		result.children += children;
		return result;
	}
	
}
