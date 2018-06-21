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

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;

import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.impl.ResourceImpl;
import org.eclipse.emf.ecore.util.EcoreUtil;
import org.eclipse.mita.base.types.Operation;
import org.eclipse.mita.base.types.PrimitiveType;
import org.eclipse.mita.base.types.Property;
import org.eclipse.mita.base.types.Type;
import org.eclipse.mita.base.types.TypeParameter;
import org.eclipse.mita.base.types.TypesFactory;

import com.google.common.collect.ArrayListMultimap;
import com.google.common.collect.ListMultimap;
import com.google.common.collect.Lists;

/**
 * Abstract base implementation if {@link ITypeSystem}. Provides convenience
 * methods to determine type compatibility.
 * 
 * @author andreas muelder - Initial contribution and API
 * 
 */
public abstract class AbstractTypeSystem implements ITypeSystem {

	protected Map<String, Type> typeRegistry = new HashMap<String, Type>();
	protected ListMultimap<Type, Type> extendsRegistry = ArrayListMultimap.create();
	protected ListMultimap<Type, Operation> extensionOperationRegistry = ArrayListMultimap.create();
	protected ListMultimap<Type, Property> extensionPropertyRegistry = ArrayListMultimap.create();

	protected Map<Type, Type> conversionRegistry = new HashMap<Type, Type>();

	protected abstract void initRegistries();

	protected Resource resource;

	public AbstractTypeSystem() {
		resource = new ResourceImpl(URI.createURI("types")) {
			@Override
			protected void doUnload() {
				// Unloading should not be performed for in memory resource
			}
		};
		initRegistries();
	}

	protected void reset() {
		typeRegistry.clear();
		extendsRegistry.clear();
		conversionRegistry.clear();
	}

	@Override
	public Type getType(String type) {
		Type result = typeRegistry.get(type);
		return result;
	}

	/**
	 * Returns all direct and indirect super types. Also reflects primitive type's
	 * base types, type parameter bounds and complex type's super types.
	 */
	@Override
	public List<Type> getSuperTypes(Type type) {
		Set<Type> allSuperTypes = new LinkedHashSet<Type>();
		collectSupertypes(type, allSuperTypes);
		return Lists.newArrayList(allSuperTypes);
	}

	/**
	 * Returns the list of direct super types for given type. Also reflects
	 * primitive type's base types, type parameter bounds and complex type's super
	 * types.
	 */
	protected List<Type> getDirectSuperTypes(Type type) {
		List<Type> superTypes = new ArrayList<Type>();
		for (Entry<Type, Type> entry : extendsRegistry.entries()) {
			if (isSame(type, entry.getKey())) {
				superTypes.add(entry.getValue());
			}
		}
		superTypes.addAll(type.getSuperTypes());
		if (type instanceof TypeParameter) {
			TypeParameter typeParameter = (TypeParameter) type;
			Type bound = typeParameter.getBound();
			if (bound != null) {
				superTypes.add(bound);
			}
		}
		return superTypes;
	}

	/**
	 * @returns <code>true</code> if superType is a direct or indirect super type of
	 *          subType.
	 */
	@Override
	public boolean isSuperType(Type subtype, Type supertype) {
		Set<Type> typehierachy = new LinkedHashSet<Type>();
		typehierachy.add(subtype);
		collectSupertypes(subtype, typehierachy);
		for (Type eObject : typehierachy) {
			if (isSame(eObject, supertype))
				return true;
		}
		return false;
	}

	/**
	 * Recursively calls itself to create list of all direct and indirect super
	 * types of given sub type
	 */
	protected void collectSupertypes(Type subType, Set<Type> typeHierachy) {
		if (subType == null)
			return;

		List<Type> superTypes = getDirectSuperTypes(subType);
		for (Type superType : superTypes) {
			typeHierachy.add(superType);
		}
		for (Type superType : superTypes) {
			collectSupertypes(superType, typeHierachy);
		}
	}

	@Override
	public Collection<Type> getTypes() {
		return Collections.unmodifiableCollection(typeRegistry.values());
	}

	@Override
	public Collection<Type> getConcreteTypes() {
		List<Type> result = new ArrayList<Type>();
		for (Type type : getTypes()) {
			if (!type.isAbstract())
				result.add(type);
		}
		return result;
	}

	protected Type declarePrimitive(String name) {
		PrimitiveType primitive = TypesFactory.eINSTANCE.createPrimitiveType();
		primitive.setName(name);
		declareType(primitive, name);
		resource.getContents().add(primitive);
		return primitive;
	}

	protected void declareType(Type type, String name) {
		typeRegistry.put(name, type);
	}

	protected void removeType(String name) {
		Type type = typeRegistry.get(name);
		if (type != null) {
			extendsRegistry.removeAll(type);
			resource.getContents().remove(type);
			typeRegistry.remove(name);
		}
	}

	protected void declareSuperType(Type subType, Type superType) {
		extendsRegistry.put(subType, superType);
	}

	protected void declareConversion(Type baseType, Type targetType) {
		conversionRegistry.put(baseType, targetType);
	}

	@Override
	public boolean haveCommonType(Type type1, Type type2) {
		return getCommonType(type1, type2) != null;
	}

	@Override
	public boolean isSame(Type type1, Type type2) {
		return EcoreUtil.equals(type1, type2);
	}

	@Override
	public Type getCommonType(Type type1, Type type2) {
		Type result = getCommonTypeInternal(type1, type2);
		if (result != null)
			return result;
		return null;
	}

	@Override
	public boolean haveCommonTypeWithConversion(Type type1, Type type2) {
		return getCommonTypeWithConversion(type1, type2) != null;
	}

	@Override
	public Type getCommonTypeWithConversion(Type type1, Type type2) {
		Type result = getCommonType(type1, type2);
		if (result != null)
			return result;
		Type conversionType1 = getConversionType(type1);
		if (conversionType1 != null) {
			result = getCommonTypeInternal(conversionType1, type2);
			if (result != null)
				return result;
		}
		Type conversionType2 = getConversionType(type2);
		if (conversionType2 != null)
			return getCommonTypeInternal(type1, conversionType2);
		return null;
	}

	protected Type getCommonTypeInternal(Type type1, Type type2) {

		if (isSame(type1, type2))
			return type1;
		if (isSuperType(type1, type2)) {
			return type2;
		}
		if (isSuperType(type2, type1))
			return type1;

		Set<Type> typehierachy1 = new LinkedHashSet<Type>();
		collectSupertypes(type1, typehierachy1);

		Set<Type> typehierachy2 = new LinkedHashSet<Type>();
		collectSupertypes(type2, typehierachy2);

		for (Type type : typehierachy1) {
			if (typehierachy2.contains(type)) {
				return type;
			}
		}
		for (Type type : typehierachy2) {
			if (typehierachy1.contains(type)) {
				return type;
			}
		}

		return null;
	}

	protected Type getConversionType(Type sourceType) {
		return conversionRegistry.get(sourceType);
	}

	public Resource getResource() {
		return resource;
	}

	@Override
	public boolean isBuiltInType(Type type) {
		return false;
	}

	@Override
	public List<Operation> getOperationExtensions(Type type) {
		List<Operation> result = new ArrayList<>();
		result.addAll(extensionOperationRegistry.get(type));
		List<Type> superTypes = getSuperTypes(type);
		for (Type superType : superTypes) {
			result.addAll(extensionOperationRegistry.get(superType));
		}
		return result;
	}

	@Override
	public boolean isExtensionOperation(Operation op) {
		return extensionOperationRegistry.containsValue(op);
	}

	@Override
	public List<Property> getPropertyExtensions(Type type) {
		List<Property> result = new ArrayList<>();
		result.addAll(extensionPropertyRegistry.get(type));
		List<Type> superTypes = getSuperTypes(type);
		for (Type superType : superTypes) {
			result.addAll(extensionPropertyRegistry.get(superType));
		}
		return result;
	}

	@Override
	public boolean isExtensionProperty(Property prop) {
		return extensionPropertyRegistry.containsValue(prop);
	}
}
