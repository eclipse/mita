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

package org.eclipse.mita.base.scoping

import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.SumSubTypeConstructor
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.mita.base.types.TypeAccessor

class TypeQualifiedNameProvider extends BaseQualifiedNameProvider {
	dispatch def doGetFullyQualifiedName(SumSubTypeConstructor f) {
		val sumAlt = f.eContainer as SumAlternative;
		val sumType = sumAlt.eContainer;
		val pkg = sumType.eContainer;
		
		val baseQID = pkg?.fullyQualifiedName;
		val autoQID = if(baseQID === null) {
			QualifiedName.create("<auto>");
		}
		else {
			baseQID.append("<auto>");
		}
		
		return autoQID.append(sumAlt.name);
	}
	
	dispatch def doGetFullyQualifiedName(SumAlternative sumAlt) {
		val sumType = sumAlt.eContainer;
		val pkg = sumType.eContainer;
		
		val baseQID = pkg?.fullyQualifiedName;
		val autoQID = if(baseQID === null) {
			QualifiedName.create("<auto>");
		}
		else {
			baseQID.append("<auto>");
		}
		
		return autoQID.append(sumAlt.name);
	}
	
	dispatch def doGetFullyQualifiedName(TypeAccessor acc) {
		return getFullyQualifiedName(acc.eContainer.eContainer.eContainer).append(acc.name);
	}
}