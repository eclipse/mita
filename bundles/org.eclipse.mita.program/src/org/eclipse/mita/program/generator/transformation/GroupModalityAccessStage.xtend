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

import org.eclipse.mita.platform.Modality
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.ProgramBlock
import java.util.HashMap
import java.util.HashSet
import java.util.List
import org.eclipse.emf.common.util.EList
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.program.ModalityAccess

class GroupModalityAccessStage extends AbstractTransformationStage {
	
	override getOrder() {
		// Make sure we run after the unravel modality access stage
		UnravelModalityAccessStage.ORDER.afterwards()
	}
	
	static def afterwards(int x) {
		return x + 10;
	}
	
	def protected dispatch doTransform(ProgramBlock obj) {
		obj.transformChildren
		
		val preparationCollapseMap = new HashMap<String, ModalityAccessPreparation>();
		for(statement : obj.content) {
			if(statement instanceof ModalityAccessPreparation) {
				val systemResourceName = statement.systemResource.name;
				val resourceAlradyPrepared = preparationCollapseMap.containsKey(systemResourceName);
				val readAlreadyPrepared = resourceAlradyPrepared && (preparationCollapseMap.get(systemResourceName).containsAnyModality(statement.modalities));

				if(resourceAlradyPrepared && !readAlreadyPrepared) {
					// add modalities to prep from prepCollapseMap
					val colapseTarget = preparationCollapseMap.get(systemResourceName);
					colapseTarget.modalities.addAll(statement.modalities);
					
					val newObj = colapseTarget;
					addPostTransformation[ statement.replaceAllReferencesWith(newObj, obj) ];
					addPostTransformation[ statement.removeFromParent() ];
				} else if(resourceAlradyPrepared && readAlreadyPrepared) {
					// reset resource in prepCollapseMap
					preparationCollapseMap.put(systemResourceName, statement);
				} else {
					// add prep to prepCollapseMap
					preparationCollapseMap.put(systemResourceName, statement);
				}
			} else if(statement.eContents.filter(ProgramBlock).empty) {
				// any statement without a ProgramBlock does not break the modality access prep collapse
			} else {
				preparationCollapseMap.clear();
			}
		}
	}
	
	def boolean containsAnyModality(ModalityAccessPreparation preparation, EList<Modality> list) {
		val presentModalityNames = new HashSet(preparation.modalities.map[ it.name ]);
		return list.exists[ presentModalityNames.contains(it.name) ];
	}
	
	def void removeFromParent(EObject obj) {
		val parent = obj.eContainer;
		if(obj.eContainingFeature.isMany) {
			(parent.eGet(obj.eContainingFeature) as List<EObject>).remove(obj);
		} else {
			parent.eSet(obj.eContainingFeature, null);
		}
	}
	
	def void replaceAllReferencesWith(EObject oldObj, EObject newObj, EObject context) {
		context.eAllContents.filter(ElementReferenceExpression).filter[ it.reference == oldObj ].forEach[ it.reference = newObj ]
		context.eAllContents.filter(FeatureCall).filter[ it.reference == oldObj ].forEach[ it.reference = newObj ]
		context.eAllContents.filter(ModalityAccess).filter[ it.preparation == oldObj ].forEach[ it.preparation = newObj as ModalityAccessPreparation ]
	}
	
	
	
}