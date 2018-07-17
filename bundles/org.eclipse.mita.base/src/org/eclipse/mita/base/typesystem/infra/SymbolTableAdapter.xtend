package org.eclipse.mita.base.typesystem.infra

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.HashMap
import java.util.Map
import org.eclipse.emf.common.notify.impl.AdapterImpl
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.mita.base.typesystem.solver.SymbolTable

class SymbolTableAdapter extends AdapterImpl {
	
	protected val Map<URI, SymbolTable> tables = new HashMap();
	
	static class SymbolTableAdapterHandler {
		@Inject Provider<SymbolTable> symbolTableProvider;
		
		def void addTable(EObject to, SymbolTable table) {
			val resource = to.eResource;
			val resourceSet = resource?.resourceSet;
			if(resourceSet === null) {
				return;
			}
			val adapter = ensureAdapter(resourceSet);
			if(adapter.tables.containsKey(resource.URI)) {
				//throw new IllegalArgumentException("Resource already has symbolTable: " + resource.URI.lastSegment)
			}
			adapter.tables.put(resource.URI, table)
		}
		
		def void removeAllTables(EObject from) {
			from.eResource?.resourceSet?.eAdapters?.removeIf[it instanceof SymbolTableAdapter];
		} 
		
		protected def ensureAdapter(ResourceSet rs) {
			val adapter = rs.eAdapters.filter(SymbolTableAdapter).head
			if(adapter === null) {
				return new SymbolTableAdapter => [
					rs.eAdapters.add(it);
				]
			}
			return adapter
		}
		
		def SymbolTable getAllSymbols(EObject context) {
			val resourceSet = context.eResource?.resourceSet
			if(resourceSet === null) {
				return null;
			}
			val adapter = ensureAdapter(resourceSet);
			
			val res = symbolTableProvider.get();
			adapter.tables.values.forEach[t |
				res.addAll(t);
			]
			
			return res;
		}	
	}
}