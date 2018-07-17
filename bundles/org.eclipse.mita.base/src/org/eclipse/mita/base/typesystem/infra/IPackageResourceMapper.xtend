package org.eclipse.mita.base.typesystem.infra

import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.xtext.naming.QualifiedName

interface IPackageResourceMapper {
	
	public def Iterable<URI> getResources(ResourceSet rs, QualifiedName packageName)
	
}