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

package org.eclipse.mita.base.typesystem.infra

import org.eclipse.emf.common.notify.impl.AdapterImpl
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor


class TypeAdapter extends AdapterImpl {
	protected AbstractType type;
	
	new() {
		type = null;
	}
	new(AbstractType type) {
		
	}
	
	static def void set(EObject obj, AbstractType type) {
		obj.adapter.type = type;
	}
	
	static def TypeAdapter getAdapter(EObject obj) {
		obj?.eAdapters?.filter(TypeAdapter)?.head ?: (
			new TypeAdapter() => [obj.eAdapters.add(it)]
		);
	}
	
	static def AbstractType get(EObject obj) {
		return obj.adapter.type;
	}
	
	public override toString() {
		return '''TypeAdapter: «type»''';
	}
	
}