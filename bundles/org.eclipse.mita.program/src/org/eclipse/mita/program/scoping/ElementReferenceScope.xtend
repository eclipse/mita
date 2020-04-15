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

package org.eclipse.mita.program.scoping

import java.util.ArrayList
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.AbstractStatement
import org.eclipse.mita.base.types.PackageAssociation
import org.eclipse.mita.base.types.TypeAccessor
import org.eclipse.mita.base.types.TypeKind
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.ForEachStatement
import org.eclipse.mita.program.ForStatement
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.IsAssignmentCase
import org.eclipse.mita.program.IsDeconstructionCase
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.ReturnParameterDeclaration
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.scoping.IScope
import org.eclipse.xtext.scoping.Scopes
import org.eclipse.xtext.scoping.impl.AbstractScope
import org.eclipse.xtext.util.SimpleAttributeResolver

import static extension org.eclipse.emf.ecore.util.EcoreUtil.*
import static extension org.eclipse.xtext.EcoreUtil2.*

class ElementReferenceScope extends AbstractScope {

	EObject context

	new(IScope outer, EObject context) {
		super(outer, false);
		this.context = context
	}
	
	override protected isShadowed(IEObjectDescription input) {
		return false;
	}
	
	override protected getAllLocalElements() {
		var result = newArrayList()
		result.addFunctionParameter(context);
		result.addProgramBlocks(context)
		result.addForLoopIterator(context)
		result.addForEachLoopIterator(context)
		result.addGlobalVariables(context)
		result.addDeconstructorVariables(context)
		result.addEventHandlerPayloadVariable(context)
		result.addStructureAccessors(context)
		Scopes.scopedElementsFor(result, [obj | 
			if(obj instanceof TypeKind) {
				return QualifiedName.create(obj.name.substring(1));
			}
			return QualifiedName.wrapper(SimpleAttributeResolver.NAME_RESOLVER).apply(obj)
		])
	}
	
	def addDeconstructorVariables(ArrayList<EObject> result, EObject context) {
		var deconstructor = context.getContainerOfType(IsDeconstructionCase)
		if(deconstructor !== null) {
			result += deconstructor.deconstructors
		}
		var assignmentDeconstructor = context.getContainerOfType(IsAssignmentCase)
		if(assignmentDeconstructor !== null) {
			result += assignmentDeconstructor.assignmentVariable
		}
	}
		
	def addStructureAccessors(ArrayList<EObject> result, EObject object) {
		result += object.getContainerOfType(PackageAssociation).types.allContents.filter(TypeAccessor).toIterable;
	}
	
	def addFunctionParameter(ArrayList<EObject> result, EObject object) {
		var container = object.getContainerOfType(FunctionDefinition)
		if(container !== null) {
			result += container.parameters
		}
	}

	def void addForLoopIterator(List<EObject> result, EObject object) {
		var container = object.getContainerOfType(ForStatement)
		if (container !== null) {
			result += container.loopVariables
			if(container.eContainer !== null) {
				result.addForLoopIterator(container.eContainer)
			}
		}
	}
	
	def void addForEachLoopIterator(List<EObject> result, EObject object) {
		var container = object.getContainerOfType(ForEachStatement)
		if (container !== null) {
			result += container.iterator
			if(container.eContainer !== null) {
				result.addForEachLoopIterator(container.eContainer)
			}
		}
	}

	def addGlobalFunctions(List<EObject> result, EObject object) {
		result += object.getContainerOfType(Program)?.functionDefinitions?.toList ?: #[]
	}

	def addGlobalVariables(List<EObject> result, EObject object) {
		result += object.getContainerOfType(Program)?.globalVariables?.toList ?: #[]
	}

	def void addProgramBlocks(List<EObject> result, EObject object) {
		var programBlock = object.getContainerOfType(ProgramBlock)
		if (programBlock !== null) {
			var index = programBlock.content.indexOf(object.getContainerOfType(AbstractStatement))
			if (index >= 0) {
				result += programBlock.content.subList(0, index).filter(VariableDeclaration).filter[!(it instanceof ReturnParameterDeclaration)]
			} else {
				result += programBlock.content.filter(VariableDeclaration).filter[!(it instanceof ReturnParameterDeclaration)]
			}
			addProgramBlocks(result, programBlock.eContainer)
		}
	}
	
	def void addEventHandlerPayloadVariable(List<EObject> result, EObject object) {
		val eventHandler = object.getContainerOfType(EventHandlerDeclaration);
		val variable = eventHandler?.payload;
		result += #[variable].filterNull
	}
}
