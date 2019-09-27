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

package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.infra.NicerTypeVariableNamesForErrorMessages
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariableProxy
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

/**
 * Corresponds to instance relationship 𝜏 ⪯ σ as defined in
 * Generalizing Hindley-Milner Type Inference Algorithms
 * by Heeren et al., see https://pdfs.semanticscholar.org/8983/233b3dff2c5b94efb31235f62bddc22dc899.pdf
 */
@Accessors
@EqualsHashCode
class ExplicitInstanceConstraint extends AbstractTypeConstraint {
	protected final AbstractType instance;
	protected final AbstractType typeScheme;
	
	override toString() {
		instance + " ⩽ " + typeScheme
	}
	
	override getErrorMessage() {
		val formatter = new NicerTypeVariableNamesForErrorMessages;
		val types = this.modifyNames(formatter) as ExplicitInstanceConstraint;
		return new ValidationIssue(_errorMessage, String.format(_errorMessage.message, types.instance, types.typeScheme));
	}
	
	new(AbstractType instance, AbstractType typeScheme, ValidationIssue errorMessage) {
		super(errorMessage);
		this.instance = instance;
		this.typeScheme = typeScheme;
	}
		
	override getTypes() {
		return #[instance, typeScheme];
	}
	
	override toGraphviz() {
		return "";
	}
	
	
	
	override map((AbstractType)=>AbstractType f) {
		val newL = f.apply(instance);
		val newR = f.apply(typeScheme);
		if(instance !== newL || instance !== newR) {
			return new ExplicitInstanceConstraint(newL, newR, _errorMessage);
		} 
		return this;
	}
	
	override getOperator() {
		return "explicit instanceof"
	}
	
	override isAtomic(ConstraintSystem system) {
		return typeScheme instanceof TypeVariableProxy
	}
	
	override hasProxy() {
		return instance.hasProxy || typeScheme.hasProxy
	}
	
}