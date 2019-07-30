/** 
 * Copyright (c) 2019 Bosch GmbH.
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 * Contributors:
 * Bosch Connected Devices and Solutions GmbH - initial contribution
 * SPDX-License-Identifier: EPL-2.0
 */
package org.eclipse.mita.program.generator

import java.util.List
import org.eclipse.xtext.generator.IFileSystemAccess2

abstract class PlatformBuildSystemGenerator {
	def void generateFiles(IFileSystemAccess2 fsa, CompilationContext context, List<String> sourceFiles)

}
