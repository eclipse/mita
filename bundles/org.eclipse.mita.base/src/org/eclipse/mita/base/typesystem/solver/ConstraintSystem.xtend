package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.ArrayList
import java.util.List
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import java.util.Collections

class ConstraintSystem {
	protected List<AbstractTypeConstraint> constraints = new ArrayList;
	protected final SymbolTable symbolTable;
	protected final TypeTable typeTable;

	@Inject new(Provider<SymbolTable> symbolTableProvider, Provider<TypeTable> typeTableProvider) {
		this.symbolTable = symbolTableProvider.get();
		this.typeTable = typeTableProvider.get();
	}
	
	protected new(SymbolTable symbolTable, TypeTable typeTable) {
		this.symbolTable = symbolTable;
		this.typeTable = typeTable;
	}
	
	def addConstraint(AbstractTypeConstraint constraint) {
		this.constraints.add(constraint);
	}
	
	def getSymbolTable() {
		return symbolTable;
	}
	
	def getTypeTable() {
		return typeTable;
	}
	
	def getConstraints() {
		return Collections.unmodifiableList(constraints);
	}
	
	override toString() {
		val res = new StringBuilder()
		
		res.append("Symbols:\n")
		res.append(symbolTable)
		res.append("\n\n")
		
		res.append("TypeTable:\n")
		res.append(typeTable)
		res.append("\n\n")
		
		res.append("Constraints:\n")
		constraints.forEach[
			res.append("\t")
			res.append(it)
			res.append("\n")
		]
		
		return res.toString
	}
	
	def takeOne() {
		val result = new ConstraintSystem(symbolTable, typeTable);
		if(constraints.empty) {
			return (null -> result);
		}
		
		result.constraints = constraints.subList(1, constraints.length);
		return constraints.get(0) -> result;
	}
	
}
