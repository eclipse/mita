/********************************************************************************
 * Copyright (c) 2018, 2019 Robert Bosch GmbH & TypeFox GmbH
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Robert Bosch GmbH & TypeFox GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.base.typesystem

import com.google.inject.Inject
import java.util.HashSet
import java.util.List
import java.util.Set
import java.util.regex.Pattern
import org.eclipse.core.runtime.CoreException
import org.eclipse.core.runtime.IStatus
import org.eclipse.core.runtime.Status
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.types.NativeType
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.BaseKind
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.FloatingType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.Signedness
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeHole
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.diagnostics.Severity
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.xtext.util.OnChangeEvictingCache

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.zip
import org.eclipse.mita.base.scoping.TypesGlobalScopeProvider.ExportedFilteredScope

class StdlibTypeRegistry {
	public static val voidTypeQID = QualifiedName.create(#[/*"stdlib",*/ "void"]);
	public static val exceptionBaseTypeQID = QualifiedName.create(#[/*"stdlib",*/ "Exception"]);
	public static val stringTypeQID = QualifiedName.create(#[/*"stdlib",*/ "string"]);
	public static val floatTypeQID = QualifiedName.create(#[/*"stdlib",*/ "float"]);
	public static val doubleTypeQID = QualifiedName.create(#[/*"stdlib",*/ "double"]);
	public static val boolTypeQID = QualifiedName.create(#[/*"stdlib",*/ "bool"]);
	public static val x8TypeQID = QualifiedName.create(#[/*"stdlib",*/ 'xint8']);
	public static val u32TypeQID = QualifiedName.create(#[/*"stdlib",*/ 'uint32']);
	public static val u8TypeQID = QualifiedName.create(#[/*"stdlib",*/ 'uint8']);
	public static val integerTypeQIDs = #['xint8', 'int8', 'uint8', 'int16', 'xint16', 'uint16', 'xint32', 'int32', 'uint32'].map[QualifiedName.create(#[/*"stdlib",*/ it])];
	public static val optionalTypeQID = QualifiedName.create(#[/*"stdlib",*/ "optional"]);
	public static val referenceTypeQID = QualifiedName.create(#[/*"stdlib",*/ "reference"]);
	public static val sigInstTypeQID = QualifiedName.create(#[/*"stdlib",*/ "siginst"]);
	public static val modalityTypeQID = QualifiedName.create(#[/*"stdlib",*/ "modality"]);
	public static val arrayTypeQID = QualifiedName.create(#[/*"stdlib",*/ "array"]);
	public static val plusFunctionQID = QualifiedName.create(#["stdlib", "__PLUS__"]);
	public static val minusFunctionQID = QualifiedName.create(#["stdlib", "__MINUS__"]);
	public static val timesFunctionQID = QualifiedName.create(#["stdlib", "__TIMES__"]);
	public static val divisionFunctionQID = QualifiedName.create(#["stdlib", "__DIVISION__"]);
	public static val moduloFunctionQID = QualifiedName.create(#["stdlib", "__MODULO__"]);
	public static val leftShiftFunctionQID = QualifiedName.create(#["stdlib", "__LEFTSHIFT__"]);
	public static val rightShiftFunctionQID = QualifiedName.create(#["stdlib", "__RIGHTSHIFT__"]);
	public static val postincrementFunctionQID = QualifiedName.create(#["stdlib", "__POSTINCREMENT__"]);
	public static val postdecrementFunctionQID = QualifiedName.create(#["stdlib", "__POSTDECREMENT__"]);
	
	@Inject IScopeProvider scopeProvider;
	
	protected boolean isLinking = false;
	protected OnChangeEvictingCache cache = new OnChangeEvictingCache(); 
	
	
	
	def setIsLinking(boolean isLinking) {
		this.isLinking = isLinking;
	}
	 
	def getTypeModelObject(EObject context, QualifiedName qn) {
		if(isLinking) {
			return null;
		}
		val obj = cache.get(qn, context.eResource, [|
			val scope = cache.get("SCOPE_TYPE", context.eResource, [|scopeProvider.getScope(context, TypesPackage.eINSTANCE.typeReferenceSpecifier_Type)]);
			scope.getSingleElement(qn)?.EObjectOrProxy
		]);
		return obj;
	}
	def getTypeModelObjectProxy(ConstraintSystem system, EObject context, QualifiedName qn) {
		if(isLinking) {
			return system.getTypeVariableProxy(context, TypesPackage.eINSTANCE.typeReferenceSpecifier_Type, qn);
		}
		return system.getTypeVariable(getTypeModelObject(context, qn));
	}
	
	def getModelObjects(ConstraintSystem system, EObject context, QualifiedName qn, EReference ref) {
		return getModelObjects(system, context, qn, ref, true);
	}
	
	def getModelObjects(ConstraintSystem system, EObject context, QualifiedName qn, EReference ref, boolean proxyIsLinking) {
		if(isLinking) {
			return #[system.getTypeVariableProxy(context, ref, qn, proxyIsLinking)];
		}
		val scope = scopeProvider.getScope(context, ref);
		val obj = scope.getElements(qn).map[EObjectOrProxy].map[system.getTypeVariable(it)].force;
		return obj;
	}
			
	protected def getVoidType(EObject context) {
		val voidType = getTypeModelObject(context, StdlibTypeRegistry.voidTypeQID);
		return new AtomicType(voidType, "void");
	}
	
	protected def getStringType(EObject context) {
		val stringType = getTypeModelObject(context, StdlibTypeRegistry.stringTypeQID);
		return new AtomicType(stringType, "string");
	}
	
	protected def getFloatType(EObject context) {
		val floatType = getTypeModelObject(context, StdlibTypeRegistry.floatTypeQID);
		if(floatType === null) {
			getTypeModelObject(context, StdlibTypeRegistry.floatTypeQID);
		}
		return translateNativeType(floatType as NativeType);
	}
	
	protected def getDoubleType(EObject context) {
		val doubleType = getTypeModelObject(context, StdlibTypeRegistry.doubleTypeQID);
		return translateNativeType(doubleType as NativeType);
	}
	
	public def getOptionalType(ConstraintSystem system, EObject context) {
		val optionalType = getTypeModelObject(context, StdlibTypeRegistry.optionalTypeQID) as GeneratedType;
		val typeArgs = #[system.newTypeVariable(optionalType.typeParameters.head)]
		return new TypeScheme(optionalType, typeArgs, new TypeConstructorType(optionalType, new AtomicType(optionalType, "optional"), typeArgs.map[it as AbstractType]));
	}
	
	public def getReferenceType(ConstraintSystem system, EObject context) {
		val referenceType = getTypeModelObject(context, StdlibTypeRegistry.referenceTypeQID) as GeneratedType;
		val typeArgs = #[system.newTypeVariable(referenceType.typeParameters.head)]
		return new TypeScheme(referenceType, typeArgs, new TypeConstructorType(referenceType, new AtomicType(referenceType, "reference"), typeArgs.map[it as AbstractType]));
	}
	
	protected def getModalityType(ConstraintSystem system, EObject context) {
		val modalityType = getTypeModelObject(context, StdlibTypeRegistry.modalityTypeQID) as GeneratedType;
		val typeArgs = #[system.newTypeVariable(modalityType.typeParameters.head)]
		return new TypeScheme(modalityType, typeArgs, new TypeConstructorType(modalityType, new AtomicType(modalityType, "modality"), typeArgs.map[it as AbstractType]));
	}
		
	public def Iterable<AbstractType> getFloatingTypes(EObject context) {
		return #[getFloatType(context), getDoubleType(context)];
	}
	def Iterable<AbstractType> getIntegerTypes(EObject context) {
		val cache = new OnChangeEvictingCache();
		
		return cache.get("STDLIB_INTEGER_TYPES", context.eResource, [|
			val typesScopeFiltered = scopeProvider.getScope(context, TypesPackage.eINSTANCE.typeReferenceSpecifier_Type);
			val typesScope = if(typesScopeFiltered instanceof ExportedFilteredScope) {
				// we want all integer types, even xint*.
				typesScopeFiltered.unfilter;
			}
			else {
				typesScopeFiltered;
			}
			StdlibTypeRegistry.integerTypeQIDs
				.map[typesScope.getSingleElement(it)?.EObjectOrProxy]
				.filter(NativeType)
				.map[translateNativeType(it)].force
		]);
	}
	
	def AbstractType translateNativeType(NativeType type) {
		val intPatternMatcher = Pattern.compile("(xint|int|uint)(\\d+)$").matcher(type?.name ?: "");
		if(intPatternMatcher.matches) {
			val signed = intPatternMatcher.group(1) == 'int';
			val unsigned = intPatternMatcher.group(1) == 'uint';
			val size = Integer.parseInt(intPatternMatcher.group(2)) / 8;
			
			new IntegerType(type, size, if(signed) Signedness.Signed else if(unsigned) Signedness.Unsigned else Signedness.DontCare);
		} else if(type?.name == "float") {
			new FloatingType(type, 4);
		} else if(type?.name == "double") {
			new FloatingType(type, 8);
		} else {
			new AtomicType(type, type.name);
		}
	}
	
}
