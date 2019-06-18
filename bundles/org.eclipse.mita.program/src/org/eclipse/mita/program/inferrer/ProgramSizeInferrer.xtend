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
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.util.EcoreUtil.UsageCrossReferencer
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.types.CoercionExpression
import org.eclipse.mita.base.types.NullTypeSpecifier
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.TypeExpressionSpecifier
import org.eclipse.mita.base.types.TypeReferenceSpecifier
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.types.TypeUtils
import org.eclipse.mita.base.types.TypedElement
import org.eclipse.mita.base.types.Variance
import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.MaxConstraint
import org.eclipse.mita.base.typesystem.infra.AbstractSizeInferrer
import org.eclipse.mita.base.typesystem.infra.FunctionSizeInferrer
import org.eclipse.mita.base.typesystem.infra.InferenceContext
import org.eclipse.mita.base.typesystem.infra.NullSizeInferrer
import org.eclipse.mita.base.typesystem.infra.SubtypeChecker
import org.eclipse.mita.base.typesystem.infra.TypeSizeInferrer
import org.eclipse.mita.base.typesystem.solver.ConstraintSolution
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.LiteralTypeExpression
import org.eclipse.mita.base.typesystem.types.NumericMaxType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.mita.program.ReturnValueExpression
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.resource.PluginResourceLoader
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.EcoreUtil2

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.zip
import org.eclipse.mita.base.typesystem.types.NumericAddType
import org.eclipse.mita.base.typesystem.constraints.SumConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.types.TypeHole

/**
 * Hierarchically infers the size of a data element.
 */
class ProgramSizeInferrer extends AbstractSizeInferrer implements TypeSizeInferrer {

	@Inject
	protected PluginResourceLoader loader;
		
	@Inject
	StdlibTypeRegistry typeRegistry;
	
	@Inject
	SubtypeChecker subtypeChecker;
	
	@Accessors 
	TypeSizeInferrer delegate = new NullSizeInferrer();
			
	override ConstraintSolution createSizeConstraints(ConstraintSolution cs, Resource r) {
		val system = new ConstraintSystem(cs.getSystem);
		system.atomicConstraints.removeIf[it instanceof SubtypeConstraint];
		val sub = new Substitution(cs.getSubstitution);
		val toBeInferred = unbindSizes(system, sub, r).force;
		toBeInferred.forEach[c| startCreatingConstraints(c)];
		
		return new ConstraintSolution(system, sub, cs.issues);	
	}
	
	override Pair<AbstractType, Iterable<EObject>> unbindSize(Resource r, ConstraintSystem system, EObject obj, AbstractType type) {
		val inferrer = getInferrer(r, null, system, type);
		if(inferrer instanceof TypeSizeInferrer) {
			inferrer.delegate = this;
			return inferrer.unbindSize(r, system, obj, type);
		}
		
		return type -> #[];
	}
	
	def Iterable<InferenceContext> unbindSizes(ConstraintSystem system, Substitution sub, Resource r) {
		val additionalUnbindings = newHashSet();
		// unbind sizes from all eobjects
		val normalInferenceContexts = r.contents.flatMap[it.eAllContents.toIterable].map[
			val tv = system.getTypeVariable(it);
			val type = sub.apply(tv);
			// unbinding may return eobjects that have to be recalculated even if they are not a generated type
			// for example EObject array<T, 5> has type array<T, uint32>, and the EObject 5 has type uint32
			// so not only array<T, 5> needs to be retyped but also 5
			val newType_blankUnbindings = unbindSize(r, system, it, type);
			val newType = newType_blankUnbindings.key;
			additionalUnbindings += newType_blankUnbindings.value;
			//TODO
			if(type !== newType) {
				// this is equivalent to removing tv from sub
				sub.addToContent(tv, tv);
				return it -> new InferenceContext(system, r, it, tv, newType);
			}
			return null;
		].filterNull.toMap([it.key], [it.value]);
		
		// only create contexts for EObjects that haven't been unbound
		additionalUnbindings.removeAll(normalInferenceContexts.keySet);
		val additionalContexts = additionalUnbindings.map[
			val tv = system.getTypeVariable(it);
			val type = sub.apply(tv);
			sub.addToContent(tv, tv);
			return new InferenceContext(system, r, it, tv, type);
		] 
		
		return normalInferenceContexts.values + additionalContexts;
	}
	
	def getInferrer(Resource r, ConstraintSystem system, AbstractType type) {
		return getInferrer(r, null, system, type)?.castOrNull(TypeSizeInferrer);
	}
	 
	/** 
	 * It's safe to pass null as obj.
	 * That means we only get the type inferrer.
	 */
	def getInferrer(Resource r, EObject obj, ConstraintSystem system, AbstractType type) {
		val typeInferrerCls = if(TypeUtils.isGeneratedType(system, type)) {
			system.getUserData(type, BaseConstraintFactory.SIZE_INFERRER_KEY);
		}
		val typeInferrer = if(typeInferrerCls !== null) { 
			loader.loadFromPlugin(r, typeInferrerCls)?.castOrNull(TypeSizeInferrer) => [
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
			loader.loadFromPlugin(obj.eResource, typeInferrerCls)?.castOrNull(FunctionSizeInferrer) => [
				it?.setDelegate(typeInferrer ?: this)]
		}
		
		return functionInferrer ?: typeInferrer
	}
	
	// only generated types have special needs for size inference for now
	def void startCreatingConstraints(InferenceContext c) {		
		val inferrer = getInferrer(c.r, c.obj, c.system, c.type);
		inferrer?.createConstraints(c);
	}
	
	static def AbstractType inferUnmodifiedFrom(ConstraintSystem system, EObject target, EObject delegate) {
		return system.associate(system.getTypeVariable(target), delegate);
	}
	
	static dispatch def void bindTypeToTypeSpecifier(ConstraintSystem s, TypedElement obj, AbstractType t) {
		if(obj.typeSpecifier instanceof PresentTypeSpecifier) {
			s.associate(t, obj.typeSpecifier);
		}
	}
	static dispatch def void bindTypeToTypeSpecifier(ConstraintSystem s, EObject obj, AbstractType t) {
	}
	
	
	override isFixedSize(TypeSpecifier ts) {
		return dispatchIsFixedSize(ts);
	}
	
	dispatch def boolean dispatchIsFixedSize(TypeExpressionSpecifier ts) {
		return StaticValueInferrer.infer(ts.value, []) !== null
	}
	dispatch def boolean dispatchIsFixedSize(TypeReferenceSpecifier ts) {
		return ts.typeArguments.forall[isFixedSize(it)];
	}
	dispatch def boolean dispatchIsFixedSize(NullTypeSpecifier ts) {
		return false;
	}
	dispatch def boolean dispatchIsFixedSize(TypeHole th) {
		return false; 
	}
	
	
	override createConstraints(InferenceContext c) {
		doCreateConstraints(c, c.obj);
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, ElementReferenceExpression obj) {
		if(obj.isOperationCall) {
			val fun = obj.reference;
			if(fun instanceof GeneratedFunctionDefinition) {
				val inferrerCls = fun.sizeInferrer;
				val inferrer = loader.loadFromPlugin(c.r, inferrerCls)?.castOrNull(FunctionSizeInferrer);
				if(inferrer !== null) { 
					inferrer.delegate = this;
					inferrer.createConstraints(c);
				}
				else {
					c.system.associate(c.type, c.tv.origin);
				}
			}
			else if(fun instanceof Operation) {
				inferUnmodifiedFrom(c.system, obj, fun.typeSpecifier);
			}
		}
		else {
			inferUnmodifiedFrom(c.system, obj, obj.reference);
		}
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, CoercionExpression obj) {
		inferUnmodifiedFrom(c.system, obj, obj.value);
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, VariableDeclaration variable) {
		val variableRoot = EcoreUtil2.getContainerOfType(variable, Program);
		val referencesToVariable = UsageCrossReferencer.find(variable, variableRoot).map[e | e.EObject ];
		val typeOrigins = (#[variable.initialization, variable.typeSpecifier.castOrNull(PresentTypeSpecifier)] + 
			referencesToVariable
				.map[it.eContainer]
				.filter(AssignmentExpression)
				.filter[ae |
					val left = ae.varRef; 
					left instanceof ElementReferenceExpression && (left as ElementReferenceExpression).reference === variable 
				]
				.map[it.expression]
		).filterNull;
		if(!typeOrigins.empty) {
			bindTypeToTypeSpecifier(c.system, variable, 
				inferUnmodifiedFrom(c.system, variable, typeOrigins.head)
			);
		}
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, PrimitiveValueExpression obj) {
		inferUnmodifiedFrom(c.system, obj, obj.value);
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, ReturnValueExpression obj) {
		inferUnmodifiedFrom(c.system, obj, obj.expression);
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, NewInstanceExpression obj) {
		inferUnmodifiedFrom(c.system, obj, obj.type);
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, TypeExpressionSpecifier typeSpecifier) {
		inferUnmodifiedFrom(c.system, typeSpecifier, typeSpecifier.value);
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, TypeReferenceSpecifier typeSpecifier) {
		// this is  t<a, b>  in  var x: t<a,  b>
		val typeArguments = typeSpecifier.typeArguments;
		val _typeConsType = c.type;
		// t
		val type = c.system.getTypeVariable(typeSpecifier.type);
		val typeWithoutModifiers = if(typeArguments.empty) {
			type;
		}
		else if(_typeConsType.class == TypeConstructorType) {
			val typeConsType = _typeConsType as TypeConstructorType;
			// this type specifier is an instance of type
			// compute <a, b>
			val typeName = typeSpecifier.type.name;
			val typeArgs = typeArguments.zip(typeConsType.typeArgumentsAndVariances.tail).map[
				c.system.getTypeVariable(it.key) as AbstractType -> it.value.value;
			].force;
			// compute constraints to validate t<a, b> (argument count etc.)
			val typeInstance = new TypeConstructorType(typeSpecifier, new AtomicType(typeSpecifier.type, typeName), typeArgs);
			typeInstance;
		}
		
		// handle reference modifiers (a: &t)
		val referenceTypeVarOrigin = typeRegistry.getTypeModelObject(typeSpecifier, StdlibTypeRegistry.referenceTypeQID);
		val typeWithReferenceModifiers = typeSpecifier.referenceModifiers.flatMap[it.split("").toList].fold(typeWithoutModifiers, [t, __ | 
			new TypeConstructorType(null, new AtomicType(referenceTypeVarOrigin, "reference"), #[t -> Variance.INVARIANT]);
		])
		
		//handle optional modifier (a: t?)
		val optionalTypeVarOrigin = typeRegistry.getTypeModelObject(typeSpecifier, StdlibTypeRegistry.optionalTypeQID);
		val typeWithOptionalModifier = if(typeSpecifier.optional) {
			new TypeConstructorType(null, new AtomicType(optionalTypeVarOrigin, "reference"), #[typeWithReferenceModifiers -> Variance.INVARIANT]);
		}
		else {
			typeWithReferenceModifiers;
		}
		
		c.system.associate(typeWithOptionalModifier, typeSpecifier);
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, EObject obj) {
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
	

		
	dispatch def void doCreateConstraints(InferenceContext c, FunctionDefinition obj) {
		val explicitType = obj.typeSpecifier.castOrNull(PresentTypeSpecifier);
		if(explicitType !== null) {
			inferUnmodifiedFrom(c.system, obj, explicitType);
		}
		
		val returnedTypes = obj.eAllContents.filter(ReturnStatement).map[x | 
			c.system.getTypeVariable(x) as AbstractType;
		].force;
		if(returnedTypes.empty) {
			// can't infer anything if there are no return statements
		}
		val maxTypeVar = c.system.newTypeVariable(obj);
		c.system.addConstraint(new MaxConstraint(maxTypeVar, returnedTypes, null));
	}
	
	override void createConstraintsForMax(ConstraintSystem system, Resource r, MaxConstraint constraint) {
		val typeInferrer = getInferrer(r, system, constraint.types.head);
		if(typeInferrer !== null) {
			typeInferrer.createConstraintsForMax(system, r, constraint);
		}
		else {
			// exists instead of forall:
			// assume that constraints are well formed at this point, so mostly all the same. 
			// Some array constraints for example are max(1,2,3,uint32). For those we need to ignore uint32: 
			// its there as a type hint for other max terms such as [1,2,3]: array<*uint32*, 3>. 
			val maxType = if(constraint.arguments.exists[it instanceof LiteralTypeExpression && (it as LiteralTypeExpression<?>).getTypeArgument === Long]) {
				val u32 = typeRegistry.getTypeModelObject(r.contents.head, StdlibTypeRegistry.u32TypeQID);
				new NumericMaxType(constraint.arguments.head.origin, "maxType", system.getTypeVariable(u32), constraint.arguments.map[it -> Variance.UNKNOWN]);
			}
			else {
				subtypeChecker.getSupremum(system, constraint.types, r.contents.head);
			}
			system.addConstraint(new EqualityConstraint(constraint.target, maxType, constraint._errorMessage));
		}
	}
	override void createConstraintsForSum(ConstraintSystem system, Resource r, SumConstraint constraint) {
		val typeInferrer = getInferrer(r, system, constraint.types.head); 
		if(typeInferrer !== null) {
			typeInferrer.createConstraintsForSum(system, r, constraint);
		}
		else {
			// exists instead of forall:
			// assume that constraints are well formed at this point, so mostly all the same. 
			// Some array constraints for example are max(1,2,3,uint32). For those we need to ignore uint32: 
			// its there as a type hint for other max terms such as [1,2,3]: array<*uint32*, 3>. 
			val sumType = if(constraint.arguments.exists[it instanceof LiteralTypeExpression && (it as LiteralTypeExpression<?>).getTypeArgument === Long]) {
				val u32 = typeRegistry.getTypeModelObject(r.contents.head, StdlibTypeRegistry.u32TypeQID);
				new NumericAddType(constraint.arguments.head.origin, "sumType", system.getTypeVariable(u32), constraint.arguments.map[it -> Variance.UNKNOWN]);
			}
			else {
				subtypeChecker.getSupremum(system, constraint.types, r.contents.head);
			}
			system.addConstraint(new EqualityConstraint(constraint.target, sumType, constraint._errorMessage));
		}
	}
	
	override getZeroSizeType(InferenceContext c, AbstractType skeleton) {
		val typeInferrer = getInferrer(c.r, c.system, skeleton);
		if(typeInferrer !== null) {
			return typeInferrer.getZeroSizeType(c, skeleton);
		}
		return skeleton;
	}
	
}







// ---------------------------------------------------
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
