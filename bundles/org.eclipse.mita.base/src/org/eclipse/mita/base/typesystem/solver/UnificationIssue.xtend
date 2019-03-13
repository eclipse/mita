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

package org.eclipse.mita.base.typesystem.solver

import java.util.List
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor
@Accessors
class UnificationIssue {
	protected final Object origin;
	protected final String message;
	
	override toString() {
		return '''UnificationIssue: «message»''';
	}
	
}

class ComposedUnificationIssue extends UnificationIssue {
	protected final List<UnificationIssue> issues;
	protected new(List<UnificationIssue> issues) {
		super(null, 
		'''
		«FOR issue: issues»
		
			«issue»
		«ENDFOR»
		'''
		)
		this.issues = issues;
	}
	
	static def UnificationIssue fromMultiple(Iterable<UnificationIssue> issues) {
		val _issues = issues.filterNull.flatMap[
			if(it instanceof ComposedUnificationIssue) {
				it.issues
			}
			else {
				#[it]
			}
		].toList;
		if(_issues.size === 1) {
			return _issues.head;	
		}
		else if(!_issues.empty) {
			return new ComposedUnificationIssue(_issues);
		}
		return null;
	}
}