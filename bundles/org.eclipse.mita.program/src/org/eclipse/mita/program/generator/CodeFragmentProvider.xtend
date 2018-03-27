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

package org.eclipse.mita.program.generator

import org.eclipse.xtext.generator.trace.node.TemplateNode
import com.google.inject.Inject
import org.eclipse.xtext.generator.trace.node.CompositeGeneratorNode
import com.google.inject.Provider
import org.eclipse.xtend2.lib.StringConcatenationClient

class CodeFragmentProvider {
	
	@Inject
	protected Provider<CodeFragment> provider;
	
	@Inject 
	protected ProgramDslTraceExtensions traceExtensions;
	
	def create(CompositeGeneratorNode body) {
		val fragment = provider.get();
		fragment.getChildren().add(body);
		return fragment;
	}
	
	def create(StringConcatenationClient body) {
		val fragment = provider.get();
		fragment.getChildren().add(new TemplateNode(body, traceExtensions));
		return fragment;
	}
	
	def CodeFragment create() {
		return new CodeFragment();
	}
}