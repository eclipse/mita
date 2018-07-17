package org.eclipse.mita.base.scoping

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.infra.SymbolTableAdapter.SymbolTableAdapterHandler
import org.eclipse.mita.base.typesystem.solver.ISymbolTable
import org.eclipse.xtext.scoping.impl.AbstractDeclarativeScopeProvider

class SymbolBasedScopeProvider extends AbstractDeclarativeScopeProvider {
	@Inject 
	protected SymbolTableAdapterHandler globalTableHandler;
	
	protected def ISymbolTable getSymbols(EObject context) {
		globalTableHandler.getAllSymbols(context);
	}
		
}