package org.eclipse.mita.platform.infra

import org.eclipse.emf.ecore.EClass
import org.eclipse.mita.base.typesystem.infra.MitaTypeLinker
import org.eclipse.mita.platform.PlatformPackage
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.diagnostics.IDiagnosticProducer
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.nodemodel.util.NodeModelUtils

class PlatformLinker extends MitaTypeLinker {
		
	override shouldLink(EClass classifier) {
		super.shouldLink(classifier) || PlatformPackage.eINSTANCE.abstractSystemResource.isSuperTypeOf(classifier);
	}
	
	override protected ensureModelLinked(EObject model, IDiagnosticProducer producer) {
		if(!NodeModelUtils.findNodesForFeature(model, PlatformPackage.eINSTANCE.systemResourceAlias_Delegate).nullOrEmpty) {
			print("")
		}
		super.ensureModelLinked(model, producer)
	}
	
}