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
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.util.EcoreUtil.UsageCrossReferencer
import org.eclipse.mita.base.expressions.ArrayAccessExpression
import org.eclipse.mita.base.expressions.Argument
import org.eclipse.mita.base.expressions.ArrayAccessExpression
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.ExpressionStatement
import org.eclipse.mita.base.expressions.IntLiteral
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.expressions.ValueRange
import org.eclipse.mita.base.types.CoercionExpression
import org.eclipse.mita.base.types.GeneratedFunctionDefinition
import org.eclipse.mita.base.types.NullTypeSpecifier
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.Parameter
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.TypeExpressionSpecifier
import org.eclipse.mita.base.types.TypeHole
import org.eclipse.mita.base.types.TypeReferenceSpecifier
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.types.TypeUtils
import org.eclipse.mita.base.types.TypedElement
import org.eclipse.mita.base.types.Variance
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.MaxConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.constraints.SumConstraint
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
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.LiteralNumberType
import org.eclipse.mita.base.typesystem.types.LiteralTypeExpression
import org.eclipse.mita.base.typesystem.types.NumericAddType
import org.eclipse.mita.base.typesystem.types.NumericMaxType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.program.DereferenceExpression
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.EventHandlerVariableDeclaration
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ReturnValueExpression
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemEventSource
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.resource.PluginResourceLoader
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.diagnostics.Severity

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import static extension org.eclipse.mita.base.util.BaseUtils.zip

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
	
	static def typeVariableToTypeConstructorType(InferenceContext c, AbstractType t, TypeConstructorType skeleton) {
		val result = new TypeConstructorType(t.origin, skeleton.name, 
			#[skeleton.typeArgumentsAndVariances.head] + 
			skeleton.typeArgumentsAndVariances.tail.map[
				c.system.newTypeVariable(null) as AbstractType -> it.value;
			])
		c.system.addConstraint(new EqualityConstraint(t, result, new ValidationIssue("%s is not a composite type", t.origin)))
		return result;
	}
	
	override ConstraintSolution createSizeConstraints(ConstraintSolution cs, Resource r) {
		val system = new ConstraintSystem(cs.getSystem);
		system.atomicConstraints.removeIf[it instanceof SubtypeConstraint];
		val sub = new Substitution(cs.getSubstitution);
		val toBeInferred = unbindSizes(system, sub, r).force;
		toBeInferred.forEach[c| startCreatingConstraints(c)];
		
		return new ConstraintSolution(system, sub, cs.issues);	
	}
	
		
	override validateSolution(ConstraintSolution cs, Resource r) {
		val sizeIssues = r.contents.flatMap[it.eAllContents.toIterable].flatMap[
			val tv = cs.system.getTypeVariable(it);
			val type = cs.substitution.apply(tv);
			return validateSizeInference(r, cs.system, it, type);
		].filterNull;
		
		return new ConstraintSolution(cs.system, cs.substitution, (cs.issues + sizeIssues).force);
	}
	
		
	override validateSizeInference(Resource r, ConstraintSystem system, EObject origin, AbstractType type) {
		val inferrer = getInferrer(r, system, type);
		if(inferrer !== null) {
			return inferrer.validateSizeInference(r, system, origin, type);
		}
		return #[];
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
		if(inferrer !== null) {
			inferrer.createConstraints(c);
		}
		else {
			createConstraints(c);
		}
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
	
	dispatch def void doCreateConstraints(InferenceContext c, Argument arg) {
		inferUnmodifiedFrom(c.system, arg, arg.value);	
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, Operation op) {
		val typeArgs = op.typeParameters.map[c.system.getTypeVariable(it)].force()
		var type = c.type;
		if(type instanceof TypeScheme) {
			c.system.associate(c.type, op);
			return;
			//type = type.instantiate(c.system, op).value;
		}
		val fromType = (type as FunctionType).from;
		val toType = c.system.getTypeVariable(op.typeSpecifier);
		val funType = new FunctionType(op, new AtomicType(op), fromType, toType);
		
		c.system.associate(if(typeArgs.empty) {
			funType
		} else {
			new TypeScheme(op, typeArgs, funType);	
		}, op);
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
	
	dispatch def void doCreateConstraints(InferenceContext c, SignalInstance siginst) {
		inferUnmodifiedFrom(c.system, siginst, siginst.initialization);	
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, SystemEventSource eventSource) {
		inferUnmodifiedFrom(c.system, eventSource, eventSource.source);
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
	
	dispatch def void doCreateConstraints(InferenceContext c, IntLiteral lit) {
		if(EcoreUtil2.getContainerOfType(lit, TypeSpecifier) !== null) {
			c.system.associate(new LiteralNumberType(lit, lit.value, c.type), lit);
		}
		else {
			_doCreateConstraints(c, lit as EObject);
		}
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, ExpressionStatement stmt) {
		inferUnmodifiedFrom(c.system, stmt, stmt.expression);
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, AssignmentExpression expr) {
		inferUnmodifiedFrom(c.system, expr, expr.varRef);
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, PrimitiveValueExpression obj) {
		inferUnmodifiedFrom(c.system, obj, obj.value);
	}
			
	dispatch def void doCreateConstraints(InferenceContext c, NewInstanceExpression obj) {
		inferUnmodifiedFrom(c.system, obj, obj.type);
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, TypeExpressionSpecifier typeSpecifier) {
		inferUnmodifiedFrom(c.system, typeSpecifier, typeSpecifier.value);
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, EventHandlerVariableDeclaration variable) {
		inferUnmodifiedFrom(c.system, variable, EcoreUtil2.getContainerOfType(variable, EventHandlerDeclaration).event);
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, NullTypeSpecifier typeSpecifier) {
		val funDef = typeSpecifier.eContainer;
		if(funDef instanceof FunctionDefinition) {
			/* we are not dispatching here, since no one can specify a size inferrer for 
			 * - object FunctionDefinition
			 * - type   FunctionType
			 * 
			 * If at some point user specified size inferrers are implemented this probably changes?
			 */
			 
			 val functionContext = new InferenceContext(c, typeSpecifier.eContainer, c.system.getTypeVariable(typeSpecifier.eContainer), new FunctionType(funDef, new AtomicType(funDef, funDef.name), c.system.newTypeVariable(funDef), c.type));
			 _doCreateConstraints(functionContext, typeSpecifier.eContainer as FunctionDefinition);
			 return;
		}
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, TypeReferenceSpecifier typeSpecifier) {
		if(typeSpecifier.eContainer instanceof FunctionDefinition) {
			/* we are not dispatching here, since no one can specify a size inferrer for 
			 * - object FunctionDefinition
			 * - type   FunctionType
			 * 
			 * If at some point user specified size inferrers are implemented this probably changes?
			 */
			 
			 val functionContext = new InferenceContext(c, typeSpecifier.eContainer, c.system.getTypeVariable(typeSpecifier.eContainer));
			 _doCreateConstraints(functionContext, typeSpecifier.eContainer as FunctionDefinition);
			 return;
		}
		// this is  t<a, b>  in  var x: t<a,  b>
		val typeArguments = typeSpecifier.typeArguments;
		val _typeConsType = c.type;
		// t
		val type = c.system.getTypeVariable(typeSpecifier.type);
		val typeWithoutModifiers = if(typeArguments.empty) {
			val typeInstance = c.system.newTypeVariable(null);
			c.system.addConstraint(new ExplicitInstanceConstraint(typeInstance, type, new ValidationIssue(Severity.ERROR, '''«typeSpecifier?.toString?.replace("%", "%%")» (:: %s) is not instance of %s''', typeSpecifier, null, "")));
			typeInstance;
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
		else {
			type
		}
		
		// handle reference modifiers (a: &t)
		val referenceTypeVarOrigin = typeRegistry.getTypeModelObject(typeSpecifier, StdlibTypeRegistry.referenceTypeQID);
		val typeWithReferenceModifiers = typeSpecifier.referenceModifiers.flatMap[it.split("").toList].fold(typeWithoutModifiers, [t, __ | 
			new TypeConstructorType(null, new AtomicType(referenceTypeVarOrigin, "reference"), #[t -> Variance.INVARIANT]);
		])
		
		//handle optional modifier (a: t?)
		val optionalTypeVarOrigin = typeRegistry.getTypeModelObject(typeSpecifier, StdlibTypeRegistry.optionalTypeQID);
		val typeWithOptionalModifier = if(typeSpecifier.optional) {
			new TypeConstructorType(null, new AtomicType(optionalTypeVarOrigin, "optional"), #[typeWithReferenceModifiers -> Variance.INVARIANT]);
		}
		else {
			typeWithReferenceModifiers;
		}
		
		c.system.associate(typeWithOptionalModifier, typeSpecifier);
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, DereferenceExpression expr) {
		val referenceTypeScheme = typeRegistry.getReferenceType(c.system, expr);
		val referenceType = typeVariableToTypeConstructorType(c, 
			c.system.getTypeVariable(expr.expression),
			referenceTypeScheme.instantiate(c.system, expr).value as TypeConstructorType
		)
		c.system.associate(referenceType.typeArguments.get(1), expr);
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, Parameter obj) {
		inferUnmodifiedFrom(c.system, obj, obj.typeSpecifier);
	}
	

	dispatch def void doCreateConstraints(InferenceContext c, TypedElement obj) {
		inferUnmodifiedFrom(c.system, obj, obj.typeSpecifier);
	}

	dispatch def void doCreateConstraints(InferenceContext c, EObject obj) {
		println('''ProgramSizeInferrer: Unhandled: «obj.class.simpleName» («obj»)''')
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, Void obj) {
		println('''ProgramSizeInferrer: Unhandled: null''')
	}
			
	dispatch def void doCreateConstraints(InferenceContext c, FunctionDefinition obj) {
		val explicitType = obj.typeSpecifier.castOrNull(PresentTypeSpecifier);
		_doCreateConstraints(c, obj as Operation);
		if(explicitType !== null) {
			if(isFixedSize(explicitType)) {
				return;
			}
		}
		
		val returnedTypes = obj.eAllContents.filter(ReturnValueExpression).map[x | 
			c.system.getTypeVariable(x) as AbstractType;
		].force;
		if(returnedTypes.empty) {
			// can't infer anything if there are no return statements
			return;
		}
		val maxTypeVar = c.system.newTypeVariable(obj);
		c.system.addConstraint(new MaxConstraint(maxTypeVar, returnedTypes, new ValidationIssue("", null)));
		c.system.associate(maxTypeVar, obj.typeSpecifier);
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
	
	override wrap(InferenceContext c, EObject obj, AbstractType inner) {
		return doWrap(c, inner, obj);
	}
	
	dispatch def AbstractType doWrap(InferenceContext c, AbstractType inner, DereferenceExpression obj) {
		val referenceTypeDef = typeRegistry.getTypeModelObject(obj, StdlibTypeRegistry.referenceTypeQID);
		val referenceTypeScheme = c.system.getTypeVariable(referenceTypeDef);
		val referenceTypeInstance = c.system.newTypeVariable(obj);
		c.system.addConstraint(new ExplicitInstanceConstraint(referenceTypeInstance, referenceTypeScheme, new ValidationIssue("%s is not instance of %s", obj)));
		val result = new TypeConstructorType(obj, new AtomicType(referenceTypeDef, "reference"), #[inner].map[it -> Variance.INVARIANT]);
		c.system.addConstraint(new EqualityConstraint(result, referenceTypeInstance, new ValidationIssue("%s is not %s", obj)))
		return result;	
	}
	dispatch def AbstractType doWrap(InferenceContext c, AbstractType inner, ArrayAccessExpression obj) {
		if(obj.arraySelector instanceof ValueRange) {
			// no unwrapping, its a subarray
			// TODO does this influence sizes?
			return inner;
		}
		val arrayTypeDef = typeRegistry.getTypeModelObject(obj, StdlibTypeRegistry.arrayTypeQID);
		val arrayTypeScheme = c.system.getTypeVariable(arrayTypeDef);
		val arrayTypeInstance = c.system.newTypeVariable(obj);
		c.system.addConstraint(new ExplicitInstanceConstraint(arrayTypeInstance, arrayTypeScheme, new ValidationIssue("%s is not instance of %s", obj)));
		val result = new TypeConstructorType(obj, new AtomicType(arrayTypeDef, "array"), #[inner, c.system.newTypeVariable(null)].map[it -> Variance.INVARIANT]);
		c.system.addConstraint(new EqualityConstraint(result, arrayTypeInstance, new ValidationIssue("%s is not %s", obj)))
		return result;	
	}
	
	dispatch def AbstractType doWrap(InferenceContext c, AbstractType inner, EObject obj) {
		return inner;
	}	
}
