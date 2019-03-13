package org.eclipse.mita.program.typesystem

import org.eclipse.emf.ecore.EClass
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.platform.PlatformPackage
import org.eclipse.mita.platform.infra.PlatformLinker

class ProgramLinker extends PlatformLinker {
	
	override shouldLink(EClass classifier) {
		super.shouldLink(classifier) 
		|| TypesPackage.eINSTANCE.systemResourceEvent.isSuperTypeOf(classifier)
		|| TypesPackage.eINSTANCE.event.isSuperTypeOf(classifier)
		|| PlatformPackage.eINSTANCE.configurationItem.isSuperTypeOf(classifier)
	}
	
}