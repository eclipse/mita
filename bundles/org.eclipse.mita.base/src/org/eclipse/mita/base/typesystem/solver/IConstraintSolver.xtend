/** 
 * Copyright (c) 2018, 2019 Robert Bosch GmbH & TypeFox GmbH
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 * Contributors:
 * Robert Bosch GmbH & TypeFox GmbH - initial contribution
 * SPDX-License-Identifier: EPL-2.0
 */
package org.eclipse.mita.base.typesystem.solver

import org.eclipse.emf.ecore.EObject

interface IConstraintSolver {
	def ConstraintSolution solve(ConstraintSolution system, EObject typeResolutionOrigin)
}

class NullSolver implements IConstraintSolver {

	override ConstraintSolution solve(ConstraintSolution system, EObject typeResolutionOrigin) {
		return system;
	}

}
