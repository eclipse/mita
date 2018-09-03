package org.eclipse.mita.platform.infra

import org.eclipse.emf.ecore.EClass
import org.eclipse.mita.base.typesystem.infra.MitaTypeLinker
import org.eclipse.mita.platform.PlatformPackage

class PlatformLinker extends MitaTypeLinker {
		
	override shouldLink(EClass classifier) {
		super.shouldLink(classifier) || PlatformPackage.eINSTANCE.abstractSystemResource.isSuperTypeOf(classifier);
	}
	
}