package org.eclipse.mita.base.typesystem.infra

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.linking.impl.Linker

class MitaLinker extends Linker {

	override protected isClearAllReferencesRequired(Resource resource) {
		false
	}
	
}
