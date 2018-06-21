/**
 * Copyright (c) 2015 committers of YAKINDU and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 * Contributors:
 * 	committers of YAKINDU - initial API and implementation
 * 
 */
package org.eclipse.mita.base.types.typesystem;

import static org.eclipse.mita.base.types.typesystem.ITypeSystem.BOOLEAN;
import static org.eclipse.mita.base.types.typesystem.ITypeSystem.INTEGER;
import static org.eclipse.mita.base.types.typesystem.ITypeSystem.REAL;
import static org.eclipse.mita.base.types.typesystem.ITypeSystem.STRING;
import static org.eclipse.mita.base.types.typesystem.ITypeSystem.VOID;

import java.util.List;

import org.eclipse.mita.base.types.ComplexType;
import org.eclipse.mita.base.types.EnumerationType;
import org.eclipse.mita.base.types.Type;

import com.google.inject.Inject;

/**
 * 
 * @author andreas muelder - Initial contribution and API
 * 
 */
public class GenericTypeValueProvider implements ITypeValueProvider {

	@Inject
	private ITypeSystem typeSystem;

	@Override
	public Object defaultValue(Type type) {
		type = type.getOriginType();
		if (is(type, VOID)) {
			return null;
		}
		if (is(type, INTEGER)) {
			return new Long(0);
		}
		if (is(type, REAL)) {
			return new Double(0.0);
		}
		if (is(type, BOOLEAN)) {
			return Boolean.FALSE;
		}
		if (is(type, STRING)) {
			return new String("");
		}
		if (type instanceof EnumerationType) {
			return null;
		}
		if (type instanceof ComplexType) {
			return null;
		}
		List<Type> superTypes = typeSystem.getSuperTypes(type);
		if (!superTypes.isEmpty())
			return defaultValue(superTypes.get(0));
		throw new IllegalArgumentException("Unknown type " + type);
	}

	protected boolean is(Type type, String typeName) {
		return typeSystem.isSame(type, typeSystem.getType(typeName));
	}

}
