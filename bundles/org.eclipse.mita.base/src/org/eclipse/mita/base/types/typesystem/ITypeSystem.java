/**
 * Copyright (c) 2014 committers of YAKINDU and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 * Contributors:
 * 	committers of YAKINDU - initial API and implementation
 * 
 */
package org.eclipse.mita.base.types.typesystem;

import java.util.Collection;
import java.util.List;

import org.eclipse.mita.base.types.Operation;
import org.eclipse.mita.base.types.Property;
import org.eclipse.mita.base.types.Type;

/**
 * A Implementation of {@link ITypeSystem} defines all existing types and the
 * type compatibility.
 * 
 * @author andreas muelder - Initial contribution and API
 * 
 */
public interface ITypeSystem {

	public static final String STRING = "string";
	public static final String REAL = "real";
	public static final String INTEGER = "integer";
	public static final String BOOLEAN = "boolean";
	public static final String VOID = "void";
	public static final String NULL = "null";
	public static final String ANY = "any";

	public Collection<Type> getTypes();

	public Collection<Type> getConcreteTypes();

	public Type getType(String name);

	public boolean isSame(Type type1, Type type2);

	public boolean haveCommonType(Type type1, Type type2);

	public Type getCommonType(Type type1, Type type2);

	public boolean haveCommonTypeWithConversion(Type type1, Type type2);

	public Type getCommonTypeWithConversion(Type type1, Type type2);

	public List<Type> getSuperTypes(Type type);

	public boolean isSuperType(Type subtype, Type supertype);

	public boolean isBuiltInType(Type type);

	public List<Operation> getOperationExtensions(Type type);

	public List<Property> getPropertyExtensions(Type type);

	public boolean isExtensionOperation(Operation op);

	public boolean isExtensionProperty(Property prop);

}
