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

package org.eclipse.mita.base.util

import com.google.common.base.Optional
import java.util.HashMap
import java.util.Map

class PreventRecursion {
	static val Map<Object, Void> recursing = new HashMap();
	static def <T> Optional<T> preventRecursion(Object obj, () => T action) {
		preventRecursion(obj, [| Optional.fromNullable(action.apply)], [| return Optional.absent]);
	}
	static def <T> T preventRecursion(Object obj, () => T action, () => T onRecursion) {
		if(recursing.containsKey(obj)) {
			return onRecursion.apply();
		}
		recursing.put(obj, null);
		try {
			return action.apply();	
		}
		finally {
			recursing.remove(obj);
		}
	}
	static def boolean isMarked(Object obj) {
		return recursing.containsKey(obj)
	}
}