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

package org.eclipse.mita.base.config;

import org.eclipse.xtext.Grammar;
import org.eclipse.xtext.GrammarUtil;
import org.eclipse.xtext.xtext.generator.StandardLanguage;
import org.eclipse.xtext.xtext.generator.XtextGeneratorNaming;
import org.eclipse.xtext.xtext.generator.model.TypeReference;
import org.eclipse.xtext.xtext.generator.validation.ValidatorNaming;

import com.google.inject.Binder;
import com.google.inject.Inject;
import com.google.inject.Module;
import com.google.inject.util.Modules;

/**
 * As our validator is inheriting from the Expression language validator which has 'Java' in its name 
 * (ExpressionsJavaValidator instead of ExpressionsValidator) we need to adjust the computation of validator 
 * names as otherwise generation would create non-compiling code.
 * 
 */
@SuppressWarnings("restriction")
public class TypesDslWorkflowLanguage extends StandardLanguage {

	@Override
	public Module getGuiceModule() {
		return Modules.override(super.getGuiceModule()).with(new Module() {

			@Override
			public void configure(Binder binder) {
				binder.bind(ValidatorNaming.class).to(OldValidatorNaming.class);
			}
			
		});
	}
	
	private static class OldValidatorNaming extends ValidatorNaming {
		
		@Inject
		private XtextGeneratorNaming naming;
		
		@Override
		public TypeReference getValidatorClass(Grammar grammar) {
			String runtimeBasePackage = naming.getRuntimeBasePackage(grammar) + ".validation.";
			String simpleName = GrammarUtil.getSimpleName(grammar);
			String name = runtimeBasePackage + simpleName + "JavaValidator";
			return new TypeReference(name);
		}
	}
	
}
