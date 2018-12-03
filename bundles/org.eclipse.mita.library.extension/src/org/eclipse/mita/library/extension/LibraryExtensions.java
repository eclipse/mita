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

package org.eclipse.mita.library.extension;

import static com.google.common.collect.Iterables.filter;
import static com.google.common.collect.Iterables.transform;

import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;

import org.eclipse.core.runtime.IConfigurationElement;
import org.eclipse.core.runtime.Platform;
import org.eclipse.emf.common.util.URI;

import com.google.common.base.Function;
import com.google.common.base.Predicate;
import com.google.common.collect.Iterables;
import com.google.common.collect.Lists;
import com.google.common.collect.Maps;
import com.google.common.collect.Sets;
import com.google.inject.Module;

public class LibraryExtensions {

	private static final String EXTENSION_POINT_ID = "org.eclipse.mita.library.extension.type_library";

	private static final String ATTRIBUTE_ID = "id";
	private static final String ATTRIBUTE_NAME = "name";
	private static final String ATTRIBUTE_DESCRIPTION = "description";
	private static final String ATTRIBUTE_VERSION = "version";
	private static final String ATTRIBUTE_OPTIONAL = "optional";
	private static final String ATTRIBUTE_MODULE = "module";

	private static final String ELEMENT_RESOURCE_URI = "ResourceURI";
	private static final String ELEMENT_DEPENDENCY = "Dependency";
	private static final String ATTRIBUTE_URI = "uri";

	private static List<LibraryDescriptor> descriptors;

	public static List<LibraryDescriptor> getDescriptors() {
		if (descriptors == null) {
			descriptors = Lists.newArrayList();
			if (Platform.isRunning()) {
				initFromExtensions();
			}
		}
		return descriptors;
	}
	
	public static List<LibraryDescriptor> getAvailablePlatforms(){
		List<LibraryDescriptor> result = Lists.newArrayList();
		for (LibraryDescriptor libraryDescriptor : getDescriptors()) {
			if(libraryDescriptor.isOptional()) {
				result.add(libraryDescriptor);
			}
		}
		return result;
	}

	public static List<LibraryDescriptor> getDefaultLibraries() {
		Map<String, LibraryDescriptor> result = Maps.newHashMap();
		List<LibraryDescriptor> allDescriptors = getDescriptors();
		for (LibraryDescriptor libraryDescriptor : allDescriptors) {
			if (libraryDescriptor.isOptional())
				continue;
			if (result.containsKey(libraryDescriptor.getId())) {
				LibraryDescriptor currentDescriptor = result.get(libraryDescriptor.getId());
				if (currentDescriptor.getVersion().compareTo(libraryDescriptor.getVersion()) < 0) {
					result.put(libraryDescriptor.getId(), libraryDescriptor);
				}
			} else {
				result.put(libraryDescriptor.getId(), libraryDescriptor);
			}
		}
		return Lists.newArrayList(result.values());
	}

	public static Iterable<LibraryDescriptor> getDescriptors(final String id) {
		return Iterables.filter(getDescriptors(), new Predicate<LibraryDescriptor>() {
			@Override
			public boolean apply(LibraryDescriptor input) {
				return id.equals(input.getId());
			}
		});
	}

	public static LibraryDescriptor getDescriptor(final String id, final Version version) {
		try {
			return Iterables.find(getDescriptors(), new Predicate<LibraryDescriptor>() {
				@Override
				public boolean apply(LibraryDescriptor input) {
					return id.equals(input.getId()) && input.getVersion().equals(version);
				}
			});
		} catch (NoSuchElementException ex) {
			return null;
		}
	}

	public static Iterable<Version> getAvailableVersions(final String id) {
		Iterable<Version> allVersions = transform(filter(getDescriptors(), new Predicate<LibraryDescriptor>() {
			@Override
			public boolean apply(LibraryDescriptor input) {
				return id.equals(input.getId());
			}
		}), new Function<LibraryDescriptor, Version>() {
			@Override

			public Version apply(LibraryDescriptor input) {
				return input.getVersion();
			}
		});
		return Sets.newTreeSet(allVersions);
	}

	protected static void initFromExtensions() {
		IConfigurationElement[] configurationElements = Platform.getExtensionRegistry()
				.getConfigurationElementsFor(EXTENSION_POINT_ID);
		for (IConfigurationElement element : configurationElements) {
			descriptors.add(createLibrary(element));
		}
	}

	protected static LibraryDescriptor createLibrary(IConfigurationElement element) {
		String id = element.getAttribute(ATTRIBUTE_ID);
		String name = element.getAttribute(ATTRIBUTE_NAME);
		String description = element.getAttribute(ATTRIBUTE_DESCRIPTION);
		Version version = Version.fromString(element.getAttribute(ATTRIBUTE_VERSION));
		boolean optional = Boolean.valueOf(element.getAttribute(ATTRIBUTE_OPTIONAL));
		
		IConfigurationElement[] children = element.getChildren(ELEMENT_RESOURCE_URI);
		List<URI> resourceURIs = Lists.newArrayList();
		for (IConfigurationElement resourceURI : children) {
			resourceURIs.add(URI.createURI(resourceURI.getAttribute(ATTRIBUTE_URI)));
		}
		IConfigurationElement[] dependencyElements = element.getChildren(ELEMENT_DEPENDENCY);
		List<String> dependencies = Lists.newArrayList();
		for (IConfigurationElement currentDependency : dependencyElements) {
			dependencies.add(currentDependency.getAttribute(ATTRIBUTE_ID));
		}
		return new LibraryDescriptor(id, name, description, version, resourceURIs, optional);
	}

	public static LibraryDescriptor getContainingLibrary(URI uri) {
		List<LibraryDescriptor> descriptors2 = getDescriptors();
		for (LibraryDescriptor libraryDescriptor : descriptors2) {
			if (libraryDescriptor.getResourceUris().contains(uri))
				return libraryDescriptor;
		}
		return null;
	}

	public static class LibraryDescriptor {

		private String id;
		private String name;
		private String description;
		// TODO: Move the version class to a non-ui plugin
		private Version version;
		private List<URI> resourceUris;
		private boolean optional;
		private List<String> dependencies;
		private Module module;

		public LibraryDescriptor(String id, String name, String description, Version version, List<URI> resourceUris, boolean optional) {
			this.id = id;
			this.name = name;
			this.description = description;
			this.version = version;
			this.resourceUris = resourceUris;
			this.optional = optional;
		}

		public String getId() {
			return id;
		}

		public String getName() {
			return name;
		}

		public String getDescription() {
			return description;
		}

		public Version getVersion() {
			return version;
		}

		public List<URI> getResourceUris() {
			return resourceUris;
		}

		public boolean isOptional() {
			return optional;
		}

		public List<String> getDependencies() {
			return dependencies;
		}

		@Override
		public int hashCode() {
			final int prime = 31;
			int result = 1;
			result = prime * result + ((id == null) ? 0 : id.hashCode());
			result = prime * result + ((version == null) ? 0 : version.hashCode());
			return result;
		}

		@Override
		public boolean equals(Object obj) {
			if (this == obj)
				return true;
			if (obj == null)
				return false;
			if (getClass() != obj.getClass())
				return false;
			LibraryDescriptor other = (LibraryDescriptor) obj;
			if (id == null) {
				if (other.id != null)
					return false;
			} else if (!id.equals(other.id))
				return false;
			if (version == null) {
				if (other.version != null)
					return false;
			} else if (!version.equals(other.version))
				return false;
			return true;
		}

		public Module getModule() {
			return module;
		}

	}
}
