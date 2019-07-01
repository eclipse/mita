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

package org.eclipse.mita.program.generator.transformation

import com.google.inject.Inject
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.mita.base.expressions.ExpressionsFactory
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.types.GeneratedFunctionDefinition
import org.eclipse.mita.base.types.NullTypeSpecifier
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.Type
import org.eclipse.mita.base.types.TypesFactory
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramFactory
import org.eclipse.mita.program.SystemEventSource
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.generator.MainSystemResourceGenerator
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.scoping.IScopeProvider

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import static extension org.eclipse.mita.base.util.BaseUtils.computeOrigin

class AddEventHandlerRingbufferStage extends AbstractTransformationStage {

	@Inject
	IScopeProvider scopeProvider
		
	@Inject(optional=true)
	protected MainSystemResourceGenerator queueSizeProvider

	override getOrder() {
		return before(AddExceptionVariableStage.ORDER);
	}
	
	protected dispatch def void doTransform(EventHandlerDeclaration decl) {
		val varDecl = addRingbufferDeclaration(decl);
		if(varDecl === null) {
			return;
		}
		addRingbufferPop(decl, varDecl);
	}
	
	protected def void addRingbufferPop(EventHandlerDeclaration decl, VariableDeclaration ringBuffer) {
		val pf = ProgramFactory.eINSTANCE;
		val tf = TypesFactory.eINSTANCE;
		val ef = ExpressionsFactory.eINSTANCE;
		
		val block = decl.block;
		
		val scope = scopeProvider.getScope(decl, ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference);
		val popFunctions = scope.getElements(QualifiedName.create("pop"))
			.map[it.EObjectOrProxy]
			.filter(GeneratedFunctionDefinition)
			.filter[it.generator.contains("RingbufferGenerator")];
		val popFunction = popFunctions.head;
		
		if(popFunction === null) {
			println("function 'pop' not in scope");
			return;
		}
		
		val popCallExpression = ef.createElementReferenceExpression;
		popCallExpression.reference = popFunction;
		
		val rbReferenceArg = ef.createArgument;
		val rbReference = ef.createElementReferenceExpression;
		rbReference.reference = ringBuffer;
		rbReferenceArg.value = rbReference;
		popCallExpression.arguments += rbReferenceArg;
		popCallExpression.operationCall = true;
		
		val popCallStmts = if(decl.payload === null) {
			val stmt = ef.createExpressionStatement;
			stmt.expression = popCallExpression;
			#[stmt];
		}
		else {
			val vdecl = pf.createEventHandlerVariableDeclaration;
			vdecl.name = decl.payload.name;	
			vdecl.initialization = popCallExpression;
			vdecl.typeSpecifier = tf.createNullTypeSpecifier;
			
			#[vdecl as VariableDeclaration];
		}
		
		block.content.addAll(0, popCallStmts);
	}
	
	protected def VariableDeclaration addRingbufferDeclaration(EventHandlerDeclaration decl) {
		val type = BaseUtils.getType(decl.event.computeOrigin);
		if(type === null || type instanceof TypeVariable) {
			// no payload for this event --> free type var
			return null;
		}
		
		val program = EcoreUtil2.getContainerOfType(decl, Program);
		if(program === null) {
			return null;
		}
		
		val eventTypeSpec = decl.event.castOrNull(SystemEventSource)?.source?.typeSpecifier;
		if(eventTypeSpec === null || eventTypeSpec instanceof NullTypeSpecifier) {
			println("Event has type but is not linked");
			return null;
		}
		
		val scope = scopeProvider.getScope(decl, TypesPackage.eINSTANCE.typeReferenceSpecifier_Type);
		val rbTypeDescription = scope.getElements(QualifiedName.create("ringbuffer")).head;
		val rbType = rbTypeDescription?.EObjectOrProxy?.castOrNull(Type);
		if(rbType === null || rbType instanceof NullTypeSpecifier) {
			println("ringbuffer not found");
			return null;
		}
		
		val pf = ProgramFactory.eINSTANCE;
		val tf = TypesFactory.eINSTANCE;
		val ef = ExpressionsFactory.eINSTANCE;
		
		// let rb_everyButtonOnePressed...
		val rbDeclaration = pf.createVariableDeclaration;
		rbDeclaration.name = "rb_" + decl.baseName;
		rbDeclaration.writeable = false;
		
		// : ringbuffer<...
		val rbTypeSpecifier = tf.createTypeReferenceSpecifier;
		rbTypeSpecifier.type = rbType;
		// bool, ...
		rbTypeSpecifier.typeArguments += EcoreUtil.copy(eventTypeSpec) as PresentTypeSpecifier;
		
		// 10>;
		val sizeTypeSpecifier = tf.createTypeExpressionSpecifier;
		val sizeExpression = ef.createPrimitiveValueExpression;
		val sizeLiteral = ef.createIntLiteral;
		sizeLiteral.value = queueSizeProvider.getEventHandlerPayloadQueueSize(decl);
		sizeExpression.value = sizeLiteral;
		sizeTypeSpecifier.value = sizeExpression;
		rbTypeSpecifier.typeArguments += sizeTypeSpecifier;
		
		rbDeclaration.typeSpecifier = rbTypeSpecifier;
				
		program.globalVariables += rbDeclaration;
		
		return rbDeclaration;
	}
	
}
