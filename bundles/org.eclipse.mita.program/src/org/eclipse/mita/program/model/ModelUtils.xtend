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

package org.eclipse.mita.program.model

import com.google.common.base.Optional
import com.google.inject.Inject
import java.util.TreeMap
import java.util.function.Predicate
import org.eclipse.emf.common.notify.impl.AdapterImpl
import org.eclipse.emf.common.util.EList
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.Argument
import org.eclipse.mita.base.expressions.ArgumentExpression
import org.eclipse.mita.base.expressions.ArrayAccessExpression
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.Expression
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.types.AnonymousProductType
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.types.NamedProductType
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.Parameter
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.PrimitiveType
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.Type
import org.eclipse.mita.base.types.TypesFactory
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer.InferenceResult
import org.eclipse.mita.base.typesystem.infra.IPackageResourceMapper
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Modality
import org.eclipse.mita.platform.Platform
import org.eclipse.mita.platform.SignalParameter
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.TimeIntervalEvent
import org.eclipse.mita.program.TryStatement
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.generator.internal.ProgramCopier
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.nodemodel.util.NodeModelUtils

import static extension org.eclipse.mita.base.util.BaseUtils.zip
import static extension org.eclipse.emf.common.util.ECollections.asEList

class ModelUtils {

	@Inject protected IPackageResourceMapper packageResourceMapper;

	/**
	 * Retrieves the variable declaration this nested expression is referencing.
	 * 
	 * This is useful for type inferrence.
	 */
	static dispatch def VariableDeclaration getUnderlyingVariableDeclaration(ArrayAccessExpression acc) {
		acc.owner.underlyingVariableDeclaration;
	}
	static dispatch def VariableDeclaration getUnderlyingVariableDeclaration(FeatureCall fc) {
		fc.arguments.head.value.underlyingVariableDeclaration;
	}
	static dispatch def VariableDeclaration getUnderlyingVariableDeclaration(ElementReferenceExpression ere) {
		ere.reference.underlyingVariableDeclaration;
	}
	static dispatch def VariableDeclaration getUnderlyingVariableDeclaration(VariableDeclaration decl) {
		decl;	
	}
	static dispatch def VariableDeclaration getUnderlyingVariableDeclaration(EObject acc) {
		null;	
	}
	static dispatch def VariableDeclaration getUnderlyingVariableDeclaration(Void acc) {
		null;
	}
	
	
	static dispatch def Optional<EList<Parameter>> getAccessorParameters(Operation op) {
		return Optional.of(op.parameters);
	}
	static dispatch def Optional<EList<Parameter>> getAccessorParameters(StructureType st) {
		return Optional.of(st.parameters.map[it as Parameter].asEList);	
	}
	static dispatch def Optional<EList<Parameter>> getAccessorParameters(AnonymousProductType apt) {
		val tss = apt.typeSpecifiers;
		if(tss.length == 1) {
			val t0 = tss.head.type;
			return t0.getAccessorParameters;
		}
		return Optional.absent;
	}
	static dispatch def Optional<EList<Parameter>> getAccessorParameters(NamedProductType npt) {
		return Optional.of(npt.parameters.map[it as Parameter].asEList);
	}
	static dispatch def Optional<EList<Parameter>> getAccessorParameters(EObject obj) {
		Optional.absent;
	}
	static dispatch def Optional<EList<Parameter>> getAccessorParameters(Void obj) {
		Optional.absent;
	}
	
	static def <T> Optional<T> preventRecursion(EObject obj, () => T action) {
		preventRecursion(obj, [| Optional.fromNullable(action.apply)], [| return Optional.absent]);
	}
	static def <T> T preventRecursion(EObject obj, () => T action, () => T onRecursion) {
		if(PreventRecursionAdapter.isMarked(obj)) {
			return onRecursion.apply();
		}
		val adapter = PreventRecursionAdapter.applyTo(obj);
		try {
			return action.apply();	
		}
		finally {
			adapter.removeFrom(obj);
		}
	}
	static class PreventRecursionAdapter extends AdapterImpl {
		
		static def boolean isMarked(EObject obj) {
			return obj.eAdapters.exists[it instanceof PreventRecursionAdapter];
		}
		
		static def PreventRecursionAdapter applyTo(EObject target) {
			val adapter = new PreventRecursionAdapter();
			target.eAdapters.add(adapter);
			return adapter;
		}
		
		static def removeFromBySearch(EObject target) {
			target.eAdapters.removeIf[it instanceof PreventRecursionAdapter];
		}
		
		def removeFrom(EObject target) {
			target.eAdapters.remove(this);
		}
	}
	
	/**
	 * Retrieves the platform a program was written against.
	 * 
	 */
	def getPlatform(Program program) {
		val programResource = program.eResource;
		val resourceSet = programResource.resourceSet;
		
		val libraries = program.imports
			.map[ it.importedNamespace ]
			.flatMap[ packageResourceMapper.getResourceURIs(resourceSet, QualifiedName.create(it.split("\\."))) ];
		val platformResourceUris = libraries.filter[r | r.fileExtension == 'platform'];

		val platforms = platformResourceUris
			.flatMap[uri| resourceSet.getResource(uri, true).allContents.toIterable ]
			.filter(Platform)
		if (platforms.length > 1) {
			// TODO: handle this error properly
		}
		return platforms.head;
	}
	
	static def boolean containsAbstractType(InferenceResult ir) {
		return containsTypeBy(true, [t | t.abstract], ir);
	}
	
	static def boolean containsTypeBy(boolean onNull, Predicate<Type> pred, InferenceResult ir) {
		if(ir === null) {
			return onNull;
		}
		if(pred.test(ir.type)) {
			return true;
		}
		ir.bindings.fold(false, [b, x | b || containsTypeBy(onNull, pred, x)])
	}
	
	static def boolean containsAbstractType(PresentTypeSpecifier ts) {
		if(ts === null) {
			return true;
		}
		if(ts.type.abstract) {
			return true;
		}
		ts.typeArguments.fold(false, [b, x | b || x.containsAbstractType])
	}

	/**
	 * Computes the time interval of an event in milliseconds.
	 */
	static def long getIntervalInMilliseconds(TimeIntervalEvent event) {
		val base = event.interval.value;
		val factor = switch event.unit {
			case MILLISECOND: 1
			case SECOND: 1000
			case MINUTE: 60 * 1000
			case HOUR: 60 * 60 * 1000
		}
		return base * factor;
	}

	def static boolean isModalityAccess(EObject statement) {
		if (statement instanceof ElementReferenceExpression) {
			if (statement.reference instanceof Modality) {
				return true;
			}
		}
		return false;
	}

	def static PresentTypeSpecifier toSpecifier(InferenceResult inference) {
		if (inference === null) {
			return null;
		} else {
			val result = TypesFactory.eINSTANCE.createPresentTypeSpecifier;
			result.type = inference.type;
			result.typeArguments.addAll(inference.bindings.map[x|x.toSpecifier]);
			return result;
		}
	}

	static def String typeSpecifierIdentifier(PresentTypeSpecifier x) {
		val innerTypes = x.typeArguments.map[typeSpecifierIdentifier].reduce[p1, p2|p1 + ", " + p2];
		val innerString = if (innerTypes === null) {
				""
			} else {
				"<" + innerTypes + ">"
			}
		return x.type.name + innerString;
	}

	def static isInTryCatchFinally(EObject statement) {
		return statement !== null && (
				// this also checks for catch/finally, since catch/finally are children of try (try.catchStatements)
				EcoreUtil2.getContainerOfType(statement, TryStatement) !== null
			);
	}

	def static findSetupFor(Program program, Class<? extends AbstractSystemResource> type, String name) {
		// TODO: This only finds setup blocks in the same compilation unit! This is very likely to cause bugs!
		return program.setup.findFirst[it.type?.name == name]
	}
	
	def static getSortedArgumentsAsMap(Iterable<Parameter> parameters, Iterable<Argument> arguments) {
		val args = getSortedArguments(parameters, arguments);
		val map = new TreeMap<Parameter, Argument>([p1, p2 | p1.name.compareTo(p2.name)]);
		parameters.zip(args).forEach[map.put(it.key, it.value)];
		return map;
	}
	
	def static <T extends Parameter> getSortedArguments(Iterable<T> parameters, Iterable<Argument> arguments) {
		if(arguments.empty || arguments.head.parameter === null) {
			arguments;
		}
		else {
			/* Important: we must not filterNull this list as that destroys the order of arguments. It is possible
			 * that we do not find an argument matching a parameter.
			 */
			parameters.map[parm | arguments.findFirst[it.parameter?.name == parm.name]]
		}
	}
	
	def static getFunctionCallArguments(ElementReferenceExpression functionCall) {
		if(functionCall === null || !functionCall.operationCall || functionCall.arguments.empty){
			return null;
		}
		
		val funRef = functionCall.reference;
		val arguments = functionCall.arguments;
		val typesAndArgsInOrder = if(funRef instanceof FunctionDefinition) {
			zip(
				funRef.parameters.map[typeSpecifier],
				ModelUtils.getSortedArguments(funRef.parameters, arguments));
		} else if(funRef instanceof StructureType) {
			zip(
				funRef.parameters.map[typeSpecifier],
				ModelUtils.getSortedArguments(funRef.parameters, arguments));
		} else if(funRef instanceof NamedProductType) {
			zip(
				funRef.parameters.map[typeSpecifier],
				ModelUtils.getSortedArguments(funRef.parameters, arguments));
		} else if(funRef instanceof AnonymousProductType) {
			zip(
				funRef.typeSpecifiers,
				functionCall.arguments);
		} else {
			return null;
		}
		return typesAndArgsInOrder;
	}	
	
	def static boolean typeSpecifierEqualsByName(PresentTypeSpecifier ts, Object o) {
		return typeSpecifierEqualsWith([t1, t2 | t1.name == t2.name], ts, o)
	}
		
	def static boolean typeSpecifierEqualsWith((Type, Type) => Boolean equalityCheck, PresentTypeSpecifier ts1, Object o) {
		if(!(o instanceof PresentTypeSpecifier)) {
			return false;
		}
		val ts2 = o as PresentTypeSpecifier;
		if(!equalityCheck.apply(ts1.type, ts2.type) || ts1.typeArguments.length != ts2.typeArguments.length) {
			return false;
		}
		zip(ts1.typeArguments, ts2.typeArguments).fold(true, [eq, tss | eq && typeSpecifierEqualsWith(equalityCheck, tss.key, tss.value)])
	}
	
	def static boolean typeInferenceResultEqualsWith((Type, Type) => Boolean equalityCheck, InferenceResult ir1, Object o) {
		if(!(o instanceof InferenceResult)) {
			return false;
		}
		val ir2 = o as InferenceResult;
		if(!equalityCheck.apply(ir1.type, ir2.type) || ir1.bindings.length != ir2.bindings.length) {
			return false;
		}
		zip(ir1.bindings, ir2.bindings).fold(true, [eq, tss | eq && typeInferenceResultEqualsWith(equalityCheck, tss.key, tss.value)])
	}
	
	/**
	 * Finds the value of an argument based on the name of its parameter.
	 */
	def static Expression getArgumentValue(Operation op, ArgumentExpression expr, String name) {
		// first check if we find a named argument
		val namedArg = expr.arguments.findFirst[x|x.parameter?.name == name];
		if(namedArg !== null) return namedArg.value;

		// we did not find a named arg. Let's look it up based on the index
		val sortedArgs = getSortedArguments(op.parameters, expr.arguments);
		
		var argIndex = op.parameters.indexed.findFirst[x|x.value.name == name]?.key
		// for extension methods the first arg is on the left side
		if(expr instanceof FeatureCall) {
			if(expr.operationCall) {
				if(argIndex == 0) {
					return expr.arguments.head.value;
				}
				argIndex--;	
			}
		}
		if(argIndex === null || argIndex >= sortedArgs.length) return null;

		return sortedArgs.get(argIndex)?.value;
	}
	
	def static Expression getArgumentValue(NamedProductType op, ArgumentExpression expr, String name) {
		// first check if we find a named argument
		val namedArg = expr.arguments.findFirst[x|x.parameter?.name == name];
		if(namedArg !== null) return namedArg.value;

		// we did not find a named arg. Let's look it up based on the index
		val sortedArgs = getSortedArguments(op.parameters, expr.arguments);
		
		var argIndex = op.parameters.indexed.findFirst[x|x.value.name == name]?.key
		// for extension methods the first arg is on the left side
		if(expr instanceof FeatureCall) {
			if(expr.operationCall) {
				if(argIndex == 0) {
					return expr.arguments.head.value;
				}
				argIndex--;	
			}
		}
		if(argIndex === null || argIndex >= sortedArgs.length) return null;

		return sortedArgs.get(argIndex)?.value;
	}

	def static Expression getArgumentValue(SignalInstance signalInstance, String name) {
		val init = signalInstance.initialization;
		val configuredValue = if (init instanceof ElementReferenceExpression) {
				val ref = init.reference;
				if (ref instanceof Operation) {
					ModelUtils.getArgumentValue(ref, init, name);
				} else {
					null;
				}
			} else {
				null;
			}

		val item = signalInstance.instanceOf;
		val defaultValue = (item.parameters.findFirst[ it.name == name ] as SignalParameter)?.defaultValue;
		return configuredValue ?: defaultValue;
	}

	def static getOriginalSourceCode(EObject obj) {
		val origin = ProgramCopier.computeOrigin(obj);
		val node = NodeModelUtils.getNode(origin);
		return if(node === null) null else NodeModelUtils.getTokenText(node);
	}

	static def boolean isPrimitiveType(PresentTypeSpecifier typeSpec) {
		val type = typeSpec?.type;
		return if (type instanceof PrimitiveType) {
			true
		} else if (type instanceof GeneratedType && type.name == 'optional') {
			typeSpec.typeArguments.forall[x|x.isPrimitiveType]
		} else {
			false
		}
	}	
}
