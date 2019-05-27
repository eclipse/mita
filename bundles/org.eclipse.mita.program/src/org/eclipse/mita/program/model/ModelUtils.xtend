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
import java.util.List
import java.util.function.Predicate
import org.eclipse.emf.common.util.EList
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.mita.base.expressions.Argument
import org.eclipse.mita.base.expressions.ArrayAccessExpression
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.expressions.Literal
import org.eclipse.mita.base.expressions.util.ExpressionUtils
import org.eclipse.mita.base.types.AnonymousProductType
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.NamedProductType
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.PackageAssociation
import org.eclipse.mita.base.types.Parameter
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.Type
import org.eclipse.mita.base.types.TypeLiteralSpecifier
import org.eclipse.mita.base.types.TypeReferenceSpecifier
import org.eclipse.mita.base.types.TypesUtil
import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.typesystem.types.AbstractBaseType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Modality
import org.eclipse.mita.platform.Platform
import org.eclipse.mita.platform.PlatformPackage
import org.eclipse.mita.platform.SignalParameter
import org.eclipse.mita.platform.SystemSpecification
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.TimeIntervalEvent
import org.eclipse.mita.program.TryStatement
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.mwe.ResourceDescriptionsProvider
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.resource.IContainer

import static extension org.eclipse.emf.common.util.ECollections.asEList

class ModelUtils {
	@Inject
	protected IContainer.Manager containerManager;
	
	@Inject
	protected ResourceDescriptionsProvider resourceDescriptionsProvider;
	

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
//		if(tss.length == 1) {
//			val t0 = tss.head.type;
//			return t0.getAccessorParameters;
//		}
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
	
	static dispatch def Optional<List<String>> getAccessorParameterNames(EObject context, ProdType struct) {
		val rt = getRealType(context, struct);
		if(rt instanceof ProdType) {
			return Optional.of(rt.typeArguments.tail.map[it.name].toList);
		}
		return Optional.of(#[rt.name]);
	}
	static dispatch def Optional<List<String>> getAccessorParameterNames(EObject context, Object obj) {
		Optional.absent;
	}
	static dispatch def Optional<List<String>> getAccessorParameterNames(EObject context, Void obj) {
		Optional.absent;
	}
	
	
	static def dispatch AbstractType getRealType(EObject context, AbstractType t) {
		return t;
	}
	
	static def dispatch AbstractType getRealType(EObject context, ProdType sumConstructor) {
		if(TypesUtil.getConstraintSystem(context.eResource).getUserData(sumConstructor, BaseConstraintFactory.ECLASS_KEY) == "AnonymousProductType") {
			val children = sumConstructor.typeArguments.tail;
			if(children.length == 1) {
				return getRealType(context, children.head);
			}
		}
		return sumConstructor;
	}
	
	/**
	 * Retrieves the platform a program was written against.
	 * 
	 */
	def getPlatform(ResourceSet resourceSet, Program program) {
		val resourceDescriptions = resourceDescriptionsProvider.get(resourceSet);
		val thisResourceDescription = resourceDescriptions.getResourceDescription(program.eResource.URI);
		val visibleContainers = containerManager.getVisibleContainers(thisResourceDescription, resourceDescriptions);
		
		val platforms = visibleContainers
			.flatMap[ it.exportedObjects ]
			.filter[it.EClass == PlatformPackage.eINSTANCE.systemSpecification]
			.map[it.EObjectOrProxy]
			.filter(SystemSpecification);
		
		val importStrings = program.imports
			.map[ it.importedNamespace ]
		
		val platformSpecification = platforms.filter[importStrings.contains(it.name)].head
		
		return platformSpecification?.eContents?.filter(Platform)?.head
	}
	
	static def getPackageAssociation(EObject obj) {
		return EcoreUtil2.getContainerOfType(obj, PackageAssociation);
	}
	
	static def boolean containsTypeBy(boolean onNull, Predicate<AbstractType> pred, AbstractType ir) {
		if(ir === null) {
			return onNull;
		}
		if(pred.test(ir)) {
			return true;
		}
		if(ir instanceof TypeConstructorType) {
			return ir.typeArguments.tail.fold(false, [b, x | b || containsTypeBy(onNull, pred, x)])
		}
		return false;
	}
	
	static def boolean containsAbstractType(TypeReferenceSpecifier ts) {
		if(ts === null) {
			return true;
		}
		if(ts.type.abstract) {
			return true;
		}
		ts.typeArguments.filter(TypeReferenceSpecifier).fold(false, [b, x | b || x.containsAbstractType])
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

	static dispatch def String typeSpecifierIdentifier(TypeLiteralSpecifier x) {
		return x.value.toString;
	}
	static dispatch def String typeSpecifierIdentifier(TypeReferenceSpecifier x) {
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
	
	
	def static getSortedArguments(Iterable<Parameter> parameters, Iterable<Argument> arguments) {
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
	
	
	def static boolean typeSpecifierEqualsByName(TypeReferenceSpecifier ts, Object o) {
		return typeSpecifierEqualsWith([t1, t2 | t1.name == t2.name], [t1, t2 | t1 == t2], ts, o)
	}
	
	static dispatch def boolean typeSpecifierEqualsWith((Type, Type) => Boolean typeEqualityCheck, (Literal, Literal) => Boolean valueEqualityCheck, TypeLiteralSpecifier ts1, Object o) {
		if(!(o instanceof TypeLiteralSpecifier)) {
			return false;
		}
		val ts2 = o as TypeLiteralSpecifier;
		if(!valueEqualityCheck.apply(ts1.value, ts2.value)) {
			return false;
		}
		return true;
	}
	static dispatch def boolean typeSpecifierEqualsWith((Type, Type) => Boolean typeEqualityCheck, (Literal, Literal) => Boolean valueEqualityCheck, TypeReferenceSpecifier ts1, Object o) {
		if(!(o instanceof TypeReferenceSpecifier)) {
			return false;
		}
		val ts2 = o as TypeReferenceSpecifier;
		if(!typeEqualityCheck.apply(ts1.type, ts2.type) || ts1.typeArguments.length != ts2.typeArguments.length) {
			return false;
		}
		return BaseUtils.zip(ts1.typeArguments, ts2.typeArguments).fold(true, [eq, tss | eq && typeSpecifierEqualsWith(typeEqualityCheck, valueEqualityCheck, tss.key, tss.value)])
	}
	
	def static boolean typeInferenceResultEqualsWith((AbstractType, AbstractType) => Boolean equalityCheck, AbstractType ir1, Object o) {
		if(!(o instanceof AbstractType)) {
			return false;
		}
		val ir2 = o as AbstractType;
		if(!equalityCheck.apply(ir1, ir2)) {
			return false;
		}
		if(ir1 instanceof TypeConstructorType) {
			if(ir2 instanceof TypeConstructorType) {
				if(ir1.typeArguments.length != ir2.typeArguments.length) {
					return false;
				}
				BaseUtils.zip(ir1.typeArguments.tail, ir2.typeArguments.tail).fold(true, [eq, tss | eq && typeInferenceResultEqualsWith(equalityCheck, tss.key, tss.value)])
			}
		}
		return ir1.class == ir2.class;
	}
	
	

	def static Expression getArgumentValue(SignalInstance signalInstance, String name) {
		val init = signalInstance.initialization;
		val configuredValue = if (init instanceof ElementReferenceExpression) {
				val ref = init.reference;
				if (ref instanceof Operation) {
					ExpressionUtils.getArgumentValue(ref, init, name);
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
		val origin = BaseUtils.computeOrigin(obj);
		val node = NodeModelUtils.getNode(origin);
		return if(node === null) null else NodeModelUtils.getTokenText(node);
	}
	
	static def boolean isStructuralType(AbstractType type, EObject context) {
		return type instanceof SumType || type instanceof ProdType || type.isPrimitiveType(context)
	}
	
	static def boolean isPrimitiveType(AbstractType type, EObject context) {
		if (type instanceof AtomicType) {
			return !TypesUtil.isGeneratedType(context, type);
		}
		if (type instanceof AbstractBaseType) {
			return true;
		} else if (type instanceof TypeConstructorType) {
			if(type.name == 'optional') {
				return type.typeArguments.tail.forall[x|x.isPrimitiveType(context)]
			}
		}
		return false;
		
	}	
}
