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

package org.eclipse.mita.base.typesystem.infra;

public enum CachedBoolean {
	Uncached, True, False;
	
	public static CachedBoolean from(boolean b) {
		if(b) {
			return True;
		}
		return False;
	}
	
	/**
	 * WARNING CHECK FOR CACHED FIRST!
	 * @return
	 */
	public boolean get() {
		return this == True;
	}
}