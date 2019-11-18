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

package org.eclipse.mita.program.validation

import com.google.common.base.Optional
import com.google.inject.Inject
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.ArrayAccessExpression
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.types.AnonymousProductType
import org.eclipse.mita.base.types.CoercionExpression
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.NamedProductType
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.TypeAccessor
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.types.VirtualFunction
import org.eclipse.mita.base.types.typesystem.ITypeSystem
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.DereferenceExpression
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.FunctionParameterDeclaration
import org.eclipse.mita.program.ReferenceExpression
import org.eclipse.mita.program.ReturnParameterDeclaration
import org.eclipse.mita.program.ReturnValueExpression
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.util.Triple
import org.eclipse.xtext.util.Tuples
import org.eclipse.xtext.validation.AbstractDeclarativeValidator
import org.eclipse.xtext.validation.Check
import org.eclipse.xtext.validation.EValidatorRegistrar
import org.eclipse.mita.base.types.TypeReferenceSpecifier

class ReferenceTypesValidator extends AbstractDeclarativeValidator implements IValidationIssueAcceptor {	
	@Inject ITypeSystem typeSystem

	public static final String REFERENCE_TYPE = "reference";
	
	public static final String CANT_ASSIGN_TO_REFERENCES_THAT_WERE_PASSED_IN = "Can not assign to references that were passed in.";
	public static final String CANT_REFERENCE_FUNCTION_PARAMETER_REFERENCES = "Can not reference function parameter references.";
	public static final String CANT_REFERENCE_FUNCTION_RESULTS = "Can not reference function results.";
	public static final String CANT_COPY_FUNCTION_PARAMETER_REF_REF = "Can not copy function parameters that are or contain references of references.";
	public static final String STRUCTURAL_TYPES_CANT_CONTAIN_REF_REFS = "Structural types can't contain references to references.";
	public static final String FORBIDDEN_RETURN = "Functions may not return references";
	public static final String TYPES_WITH_REFERENCES_MUST_BE_INITIALIZED = "Types with references must be initialized";
	
	// You can always read contents of references
	
	// You can never return anything with references
	// - done since we can't return anything but primities
	
	// You can always pass references to another function
	
	// You can always reference value types
	
	// You can always modify values that are referenced (that is the base values that are referenced)
	
	// You can do whatever you want to (contents of) values that you didn't get by reference
	
	// You can only set referenced references if the new reference belongs to the same person or it's ancestor as the original one (too hard --> forbidden)
	    // Therefore you can only modify your own referenced references
	@Check
	def checkAssignmentToReferenceOfReference(AssignmentExpression e) {
		
	}
	    // This also means you can't reference function parameter references
	    // This also means you can't copy reference references from function parameters
	@Check
	def checkAssignmentStatement(AssignmentExpression e) {
		if(e.expression !== null) {
			checkRHS1(e, e.expression)
			checkLHS1(e, e.varRef)
		}
	}
	@Check
	def checkVariableDeclaration(VariableDeclaration e) {
		if(e instanceof ReturnParameterDeclaration) {
			return;
		}
		if(e.initialization !== null) {
			checkRHS1(e, e.initialization)	
		}
		else {
			val typeIR = BaseUtils.getType(e);
			if(typeIR.hasReferenceInType) {
				error(TYPES_WITH_REFERENCES_MUST_BE_INITIALIZED, e, null);
			}
		}
	}
	def checkLHS1(EObject source, Expression varRef) {
		//check if ref is from function parameters
		val isRefRef = innerMostReferences(varRef);

		val outerType = BaseUtils.getType(varRef);
		
		if (outerType?.name == "reference" && isRefRef.second) {
			error(CANT_ASSIGN_TO_REFERENCES_THAT_WERE_PASSED_IN, source, null);
		}
		return;
		
	}
	
	@Check
	def checkNoRefOfFunResult(ReferenceExpression e) {
		val variable = e.variable;	
		checkNoFunCall(variable, e);
	}
	@Check
	def forbiddenReferenceReturn(ReturnValueExpression stmt) {
		val funDecl = EcoreUtil2.getContainerOfType(stmt, FunctionDefinition);
		val funDeclTypeIR = BaseUtils.getType(funDecl.typeSpecifier);
		if(hasReferenceInType(funDeclTypeIR)) {
			error(FORBIDDEN_RETURN, stmt, null);
		}
	}
	
	@Check
	def forbiddenReferenceReturn(FunctionDefinition funDecl) {
		if(funDecl.typeSpecifier === null) {
			return;
		}
		val funDeclTypeIR = BaseUtils.getType(funDecl.typeSpecifier);
		if(hasReferenceInType(funDeclTypeIR)) {
			error(FORBIDDEN_RETURN, funDecl, TypesPackage.Literals.NAMED_ELEMENT__NAME);
		}
	}
	
	def boolean hasReferenceInType(AbstractType type) {
		if(type === null) {
			return false;
		}
		if(type.name == "reference") {
			return true;
		}
		if(type instanceof TypeConstructorType) {
			return type.typeArguments.tail.fold(false, [b, i | b || i.hasReferenceInType])			
		}
		return false;
	}
	
	dispatch def void checkNoFunCall(ArrayAccessExpression a, EObject source) {
		a.owner.checkNoFunCall(source);
	}
	dispatch def void checkNoFunCall(ElementReferenceExpression a, EObject source) {
		if(a.operationCall && !(a.reference instanceof VirtualFunction)) {
			error(CANT_REFERENCE_FUNCTION_RESULTS, source, null);
		}
		if(a.reference !== null) {
			a.reference.checkNoFunCall(source);
		}
	}
	dispatch def void checkNoFunCall(CoercionExpression e, EObject source) {
		e.value.checkNoFunCall(source);
	}
	dispatch def void checkNoFunCall(EObject e, EObject source) {
	}
	dispatch def void checkNoFunCall(Void e, EObject source) {
		throw new NullPointerException;
	}
	
	
	dispatch def void checkRHS1(EObject source, ReferenceExpression e) {
		checkRHS1(source, e.variable);
	}
	
	dispatch def void checkRHS1(EObject source, EObject e) {
		// check if ref is from function parameters
		val ref = innerMostReferences(e);
		if(ref.second) {
			// the final type must be without references
			val eType = BaseUtils.getType(e);
			if(maxRefCount(eType) > 0) {
				error(CANT_COPY_FUNCTION_PARAMETER_REF_REF, source, null);
			}
		}
		return;
	}

	
	dispatch def Integer maxRefCount(TypeConstructorType s) {
		if(s.name == "reference") {
			1
		}
		else {
			0
		} + (#[0] + s.typeArguments.tail.map[it.maxRefCount]).max;
	}
	dispatch def Integer maxRefCount(Object o) {
		0;
	}
	dispatch def Integer maxRefCount(Void o) {
		0;
	}
	
	def Optional<Pair<Integer, TypeReferenceSpecifier>> typeSpecifierContainsRefRefs(PresentTypeSpecifier ts) {
		if(ts instanceof TypeReferenceSpecifier) {
			return structuralFeatureContainsRefRefs(ts.type).or(
			if(typeSystem.isSuperType(ts.type, typeSystem.getType(REFERENCE_TYPE))) {
				typeSpecifierContainsRefRefs(ts.typeArguments.head);
			}
			else {
				Optional.absent;
			})	
		}
		else {
			return Optional.absent;
		}
	}
	
	dispatch def Triple<Integer, Boolean, List<EObject>> innerMostReferences(CoercionExpression e) {
		e.value.innerMostReferences;
	}
	dispatch def Triple<Integer, Boolean, List<EObject>> innerMostReferences(DereferenceExpression e) {
		if(e.expression === null) {
			return Tuples.create(0, false, #[e as EObject]);
		}
		val ce = e.expression.innerMostReferences;
		Tuples.create(ce.first + 1, ce.second, ce.third);
	}
	
	dispatch def Triple<Integer, Boolean, List<EObject>> innerMostReferences(ElementReferenceExpression e) {
		if(e.operationCall && !(e.reference instanceof VirtualFunction)) {
			return Tuples.create(0, false, #[e as EObject]);
		}
		else if(e.reference instanceof TypeAccessor) {
			val t1 = e.reference.innerMostReferences;
			val t2 = e.arguments.head.value.innerMostReferences;
			return Tuples.create(t1.first + t2.first, t1.second || t2.second, (t1.third + t2.third).toList)
		}
		else {
			return e.reference.innerMostReferences;
		}
	}
	
	dispatch def Triple<Integer, Boolean, List<EObject>> innerMostReferences(FunctionParameterDeclaration fpd) {
		Tuples.create(0, true, #[fpd as EObject]);
	}
	
	dispatch def Triple<Integer, Boolean, List<EObject>> innerMostReferences(EObject e) {
		Tuples.create(0, false, #[e as EObject]);
	}
	
	dispatch def Triple<Integer, Boolean, List<EObject>> innerMostReferences(Void e) {
		// fall-back in case of a 'null' input
		Tuples.create(0, false, #[]);
	}
	
	dispatch def structuralFeatureContainsRefRefs(StructureType s) {
		s.parameters.map[it.typeSpecifier].filter(TypeReferenceSpecifier).typeSpecsContainRefRefs
	}
	dispatch def structuralFeatureContainsRefRefs(AnonymousProductType s) {
		s.typeSpecifiers.typeSpecsContainRefRefs
	}
	dispatch def structuralFeatureContainsRefRefs(NamedProductType s) {
		s.parameters.map[it.typeSpecifier].filter(TypeReferenceSpecifier).typeSpecsContainRefRefs
	}
	dispatch def structuralFeatureContainsRefRefs(EObject e) {
		Optional.absent;
	}
	
	def typeSpecsContainRefRefs(Iterable<TypeReferenceSpecifier> tss) {
		for(idx_ts: tss.indexed) {
			if(typeSystem.isSuperType(idx_ts.value.type, typeSystem.getType(REFERENCE_TYPE))) {
				val innerType = idx_ts.value.typeArguments.head;
				if(innerType instanceof TypeReferenceSpecifier && typeSystem.isSuperType((innerType as TypeReferenceSpecifier).type, typeSystem.getType(REFERENCE_TYPE))) {
					return Optional.of(idx_ts);
				}
			}
		}
	}
	
	@Inject
	override register(EValidatorRegistrar registrar) {
		// Do not register because this validator is only a composite #398987
	}
	
	override accept(ValidationIssue issue) {
		error(issue.message, issue.target, null);
	}
	
}