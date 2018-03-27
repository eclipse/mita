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

package org.eclipse.mita.program.generator.transformation;

import org.eclipse.emf.ecore.EObject;

/**
 * Offers reflective information about the pipeline as part of which a stage gets 
 * executed. The main purpose of this interface is to hide the implementation of the
 * pipeline itself from the stages.
 *
 */
public interface ITransformationPipelineInfoProvider {

	/**
	 * Returns true if a particular expression/statement/object will be unraveled by some pipeline stage
	 * at any point. Knowing this can be useful for preparing for that unraveling (e.g. for preparing
	 * loops).
	 * 
	 * @param obj the object to check if it's going to be unraveled or not
	 * @return true if it's going to be unraveled, false if not
	 */
	public boolean willBeUnraveled(EObject obj);
	
}
