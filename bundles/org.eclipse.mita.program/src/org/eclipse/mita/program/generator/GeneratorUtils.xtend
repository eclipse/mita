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

package org.eclipse.mita.program.generator

import com.google.inject.Inject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.nio.file.Files
import java.nio.file.Paths
import java.text.SimpleDateFormat
import java.util.Date
import java.util.function.Function
import java.util.stream.Stream
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.plugin.EcorePlugin
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.types.AnonymousProductType
import org.eclipse.mita.base.types.Event
import org.eclipse.mita.base.types.ExceptionTypeDeclaration
import org.eclipse.mita.base.types.NamedElement
import org.eclipse.mita.base.types.NamedProductType
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.Singleton
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.SumType
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Bus
import org.eclipse.mita.platform.Connectivity
import org.eclipse.mita.platform.InputOutput
import org.eclipse.mita.platform.Modality
import org.eclipse.mita.platform.Platform
import org.eclipse.mita.platform.Sensor
import org.eclipse.mita.platform.SystemResourceAlias
import org.eclipse.mita.platform.SystemResourceEvent
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.NativeFunctionDefinition
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemEventSource
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.TimeIntervalEvent
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.generator.internal.ProgramCopier
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.generator.trace.node.CompositeGeneratorNode
import org.eclipse.xtext.generator.trace.node.IGeneratorNode
import org.eclipse.xtext.generator.trace.node.NewLineNode
import org.eclipse.xtext.generator.trace.node.TextNode
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.mita.program.generator.internal.UserCodeFileGenerator
import org.eclipse.mita.base.types.StructureType

/**
 * Utility functions for generating code. Eventually this will be moved into the model.
 */
class GeneratorUtils {

	@Inject
	protected extension ProgramCopier
	
	@Inject
	protected IScopeProvider scopeProvider;
	
	@Inject 
	protected CodeFragmentProvider codeFragmentProvider;
	
	@Inject(optional = true)
	protected IPlatformLoggingGenerator loggingGenerator;

	/**
	 * Opens the file at *fileLoc* either absolute or relative to the current project, depending on whether the path is absolute or relative.
	 * In the case of the standalone compiler this will open *fileLoc* relative to the user's command.
	 * If the file does not exist, returns null.
	 */
	def Stream<String> getFileContents(Resource resourceInProject, String fileLoc) {
		val path = Paths.get(fileLoc);
		return (if(path.isAbsolute) {
			if(!Files.exists(path)) {
				null;
			}
			else {
				Files.newBufferedReader(path);
			}
		}
		else {
			val workspaceRoot = EcorePlugin.workspaceRoot;
			if(workspaceRoot === null) {
				// special case for standalone compiler
				Files.newBufferedReader(path);
			}
			else {
				val file = workspaceRoot.getProject(resourceInProject.URI.segment(1)).getFile(fileLoc);
				if(!file.exists) {
					null;
				}
				else {
			        new BufferedReader(new InputStreamReader(file.getContents(), file.charset));
				}
			}
		})?.lines;
	}

	def getGlobalInitName(Program program) {
		return '''initGlobalVariables_«program.eResource.URI.lastSegment.replace(".mita", "")»'''
	}
	def generateLoggingExceptionHandler(String resourceName, String action) {
		codeFragmentProvider.create('''
		if(exception == NO_EXCEPTION)
		{
			«loggingGenerator.generateLogStatement(IPlatformLoggingGenerator.LogLevel.Info, action + " " + resourceName + " succeeded")»
		}
		else
		{
			«loggingGenerator.generateLogStatement(IPlatformLoggingGenerator.LogLevel.Error, "failed to " + action + " " + resourceName)»
			return exception;
		}
		''')
	}
	
	def getOccurrence(EObject obj) {
		val EObject funDef = EcoreUtil2.getContainerOfType(obj, FunctionDefinition) as EObject
			?:EcoreUtil2.getContainerOfType(obj, EventHandlerDeclaration) as EObject
			?:EcoreUtil2.getContainerOfType(obj, Program) as EObject;
		val result = funDef?.eAllContents?.filter(obj.class)?.indexed?.findFirst[it.value.equals(obj)]?.key?:(-1);
		return result + 1;
	}
	
	public def String getUniqueIdentifier(EObject obj) {
		return obj.uniqueIdentifierInternal.replace(".", "_") + "_" + obj.occurrence.toString;
	} 
	
	private def dispatch String getUniqueIdentifierInternal(Program p) {
		return p.baseName;
	}
	
	private def dispatch String getUniqueIdentifierInternal(EventHandlerDeclaration decl) {
		return decl.eContainer.uniqueIdentifierInternal + decl.handlerName.toFirstUpper;
	}
	
	private def dispatch String getUniqueIdentifierInternal(FunctionDefinition funDef) {
		return funDef.eContainer.uniqueIdentifierInternal + funDef.baseName.toFirstUpper;
	}
	
	private def dispatch String getUniqueIdentifierInternal(VariableDeclaration decl) {
		return decl.eContainer.uniqueIdentifierInternal + decl.baseName.toFirstUpper;
	}
	
	private def dispatch String getUniqueIdentifierInternal(ElementReferenceExpression expr) {
		return expr.reference.uniqueIdentifierInternal;
	}
	
	private def dispatch String getUniqueIdentifierInternal(FeatureCall feature) {
		if(feature.feature instanceof SignalInstance) {
			return feature.feature.baseName.toFirstLower;
		} else {
			return feature.owner.uniqueIdentifierInternal + feature.feature.baseName.toFirstUpper;			
		}
	}
	
	private def dispatch String getUniqueIdentifierInternal(ProgramBlock pb) {
		pb.eContainer.uniqueIdentifierInternal + pb.eContainer.eAllContents.toList.indexOf(pb).toString;
	}
	
	private def dispatch String getUniqueIdentifierInternal(ReturnStatement rt) {
		return rt.eContainer.uniqueIdentifierInternal + "_result";
	}
	
	private def dispatch String getUniqueIdentifierInternal(EObject obj) {
		return obj.baseName ?: obj.eClass.name;
	}

	def dispatch String getHandlerName(EventHandlerDeclaration event) {
		val program = EcoreUtil2.getContainerOfType(event, Program);
		if(program !== null) {
			// count event handlers, so we get unique names
			var occurence = 1;
			var found = false;
			for(e: program.eventHandlers) {
				if(e.equals(event)){
					found = true;
				}
				// no break; statement => need flag
				// only count events with the same name
				if(!found && e.baseName.equals(event.baseName)) {
					occurence++;
				}
			}
			return '''HandleEvery«event.baseName»«occurence»''';
		}
		// if we are somehow not a child of program, default to no numbering
		return '''HandleEvery«event.baseName»''';
		
	}
	
	def dispatch String getHandlerName(EObject event) {
		val e = EcoreUtil2.getContainerOfType(event, EventHandlerDeclaration);
		if(e !== null) {
			return getHandlerName(e);
		}
		return '''HandleEvery«event.baseName»''';
	}
	
	def getSetupName(EObject sensor) {
		return '''«sensor.baseName»_Setup''';
	}
	
	def dispatch String getEnableName(AbstractSystemResource resource) {
		return '''«resource.baseName.toFirstUpper»_Enable'''
	}
	
	def dispatch String getEnableName(SystemResourceSetup resource) {
		return '''«resource.baseName.toFirstUpper»_Enable'''
	}
	
	def dispatch String getEnableName(EventHandlerDeclaration handler) {
		// TODO: handle named event handlers
		return handler.event.enableName
	}

	def dispatch getEnableName(TimeIntervalEvent event) {
		return '''Every«event.handlerName»_Enable''';
	}

	def dispatch getEnableName(Event event) {
		return '''Every«event.baseName»_Enable''';
	}

	def getReadAccessName(SignalInstance sira) {
		return '''«sira.baseName»_Read'''
	}
	
	def getWriteAccessName(SignalInstance siwa) {
		return '''«siwa.baseName»_Write'''
	}
	
	def getComponentAndSetup(EObject componentOrSetup, CompilationContext context) {
		val component = if(componentOrSetup instanceof AbstractSystemResource) {
			componentOrSetup
		} else if(componentOrSetup instanceof SystemResourceSetup) {
			componentOrSetup.type
		}
		val setup = if(componentOrSetup instanceof AbstractSystemResource) {
			context.getSetupFor(component)
		} else if(componentOrSetup instanceof SystemResourceSetup) {
			componentOrSetup
		}
		return component -> setup
	}

	def dispatch getFileBasename(AbstractSystemResource resource) {
		return '''«resource.baseName?.toFirstUpper»'''
	}
		
	def dispatch getFileBasename(SystemResourceSetup setup) {
		return '''«setup.baseName»'''
	}
	
	def dispatch getResourceTypeName(Bus sensor) {
		return '''Bus''';
	}
	
	def dispatch getResourceTypeName(Connectivity sensor) {
		return '''Connectivity''';
	}
	
	def dispatch getResourceTypeName(InputOutput sensor) {
		return '''InputOutput''';
	}
	
	def dispatch getResourceTypeName(Platform sensor) {
		return '''Platform''';
	}
	
	def dispatch getResourceTypeName(Sensor sensor) {
		return '''Sensor''';
	}
	
	def dispatch String getResourceTypeName(SystemResourceAlias alias) {
		return alias.delegate.resourceTypeName;
	}

	def dispatch String getBaseName(Program p) {
		return p.name?:"";
	}
	
	def dispatch String getBaseName(ElementReferenceExpression eref) {
		return eref.reference?.baseName;
	}
	
	def dispatch String getBaseName(Operation element) {
		return '''«element.name»«FOR p : element.parameters BEFORE '_' SEPARATOR '_'»«p.type.name»«ENDFOR»'''
	}
	
	def dispatch String getBaseName(AbstractSystemResource resource) {
		return '''«resource.resourceTypeName»«resource.name.toFirstUpper»'''
	}
	
	def dispatch String getBaseName(SystemResourceSetup setup) {
		'''«setup.type.baseName»«setup.name?.toFirstUpper»'''
	}
	
	def dispatch String getBaseName(NamedElement element) {
		return '''«element.name»'''
	}
	
	def dispatch String getBaseName(ExceptionTypeDeclaration event) {
		return '''EXCEPTION_«event.name.toUpperCase»'''
	}
	
	def dispatch String getBaseName(EventHandlerDeclaration event) {
		return event.event.baseName;
	}
	
	def dispatch String getBaseName(SystemEventSource event) {
		val origin = event.origin;
		return if(origin instanceof SystemResourceAlias) {
			val instanceName = origin.name;
			'''«instanceName.toFirstUpper»«event.source.name.toFirstUpper»'''
		} else {
			event.source.baseName
		}
	}
	
	def dispatch String getBaseName(SystemResourceEvent event) {
		return '''«(event.eContainer as AbstractSystemResource).name.toFirstUpper»«event.name.toFirstUpper»'''
	}
	
	def dispatch String getBaseName(TimeIntervalEvent event) {
		return '''«event.interval.value»«event.unit.literal.toFirstUpper»'''
	}
	
	def dispatch String getBaseName(Event event) {
		val parentName = EcoreUtil2.getID(event.eContainer).toFirstUpper;
		val eventName = event.name.toFirstUpper;
		return '''«parentName»«eventName»'''
	}
	
	def dispatch String getBaseName(Modality modality) {
		return '''«modality.eContainer.baseName»_«modality.name.toFirstUpper»'''
	}
	
	def dispatch String getBaseName(SignalInstance vci) {
		return '''«vci.eContainer.baseName»_«vci.name.toFirstUpper»'''
	}
	
	def dispatch String getBaseName(NativeFunctionDefinition fd) {
		return fd.name;
	}
	
	def dispatch String getBaseName(Object ob) {
		return null
	}
	
	dispatch def CodeFragment getEnumName(SumType sumType) {
		return codeFragmentProvider.create('''«sumType.name»_enum''')
			.addHeader(UserCodeFileGenerator.getResourceTypesName(ModelUtils.getPackageAssociation(sumType)) + ".h", false);
	}
	dispatch def CodeFragment getEnumName(SumAlternative singleton) {
		val parent = EcoreUtil2.getContainerOfType(singleton, SumType)
		if(parent === null) {
			return codeFragmentProvider.create('''ERROR: Model broken''')
		}
		return codeFragmentProvider.create('''«parent.name»_«singleton.name»_e''')
			.addHeader(UserCodeFileGenerator.getResourceTypesName(ModelUtils.getPackageAssociation(singleton)) + ".h", false);
	}
	
	dispatch def CodeFragment getStructName(SumType sumType) {
		return codeFragmentProvider.create('''«sumType.name»''')
			.addHeader(UserCodeFileGenerator.getResourceTypesName(ModelUtils.getPackageAssociation(sumType)) + ".h", false);
	}
	dispatch def CodeFragment getStructName(SumAlternative sumAlternative) {
		return codeFragmentProvider.create('''«sumAlternative.name»''')
			.addHeader(UserCodeFileGenerator.getResourceTypesName(ModelUtils.getPackageAssociation(sumAlternative)) + ".h", false);
	}
	dispatch def CodeFragment getStructName(StructureType structureType) {
		return codeFragmentProvider.create('''«structureType.baseName»''')
			.addHeader(UserCodeFileGenerator.getResourceTypesName(ModelUtils.getPackageAssociation(structureType)) + ".h", false);
	}
	
	dispatch def CodeFragment getStructType(Singleton singleton) {
		//singletons don't contain actual data
		return codeFragmentProvider.create('''void''')
			.addHeader(UserCodeFileGenerator.getResourceTypesName(ModelUtils.getPackageAssociation(singleton)) + ".h", false);
	}
	dispatch def CodeFragment getStructType(AnonymousProductType productType) {
		if(productType.typeSpecifiers.length > 1) {
			return codeFragmentProvider.create('''«productType.baseName»_t''')
			.addHeader(UserCodeFileGenerator.getResourceTypesName(ModelUtils.getPackageAssociation(productType)) + ".h", false);
		}
		else {
			// we have only one type specifier, so we shorten to an alias
			return codeFragmentProvider.create('''ERROR: ONLY ONE MEMBER, SO USE THAT ONE'S SPECIFIER''');
		}
	}
	dispatch def CodeFragment getStructType(NamedProductType productType) {
		return codeFragmentProvider.create('''«productType.baseName»_t''')
			.addHeader(UserCodeFileGenerator.getResourceTypesName(ModelUtils.getPackageAssociation(productType)) + ".h", false);
	}
	dispatch def CodeFragment getStructType(SumType sumType) {
		return codeFragmentProvider.create('''«sumType.name»''')
			.addHeader(UserCodeFileGenerator.getResourceTypesName(ModelUtils.getPackageAssociation(sumType)) + ".h", false);
	}
	
	def dispatch String getBaseName(Sensor sensor) {
		return sensor.name.toFirstUpper
	}
	
	def dispatch String getBaseName(ModalityAccess modalityAccess) {
		return '''«modalityAccess.preparation.baseName»«modalityAccess.modality.baseName.toFirstUpper»'''
	}
	
	def dispatch String getBaseName(ModalityAccessPreparation modality) {
		return '''«modality.systemResource.baseName»ModalityPreparation'''
	}
	
	def generateHeaderComment(CompilationContext context) {
		'''
		/**
		 * Generated by Eclipse Mita «context.mitaVersion».
		 * @date «new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date())»
		 */

		'''
	}
	
	def generateExceptionHandler(EObject context, String variableName) {
		'''
			«IF variableName != 'exception'»exception = «variableName»;«ENDIF»
			if(exception != NO_EXCEPTION) «IF ModelUtils.isInTryCatchFinally(context)»break«ELSE»return «variableName»«ENDIF»;
		''' 
	}
	
	def IGeneratorNode trim(IGeneratorNode stmt, boolean lastOccurance, Function<CharSequence, CharSequence> trimmer) {
		if (stmt instanceof TextNode) {
			stmt.text = trimmer.apply(stmt.text);
		} else if (stmt instanceof CompositeGeneratorNode) {
			val trimmableNodePrefix = [ IGeneratorNode node |
				var isNewLineNode = node instanceof NewLineNode;
				var isEmptyTextNode = if(node instanceof TextNode) {
					node.text.length == 0
				} else if(node instanceof CodeFragment) {
					node == CodeFragment.EMPTY
				} else {
					false
				}
				return !(isNewLineNode || isEmptyTextNode);
			]
			
			val child = if (!lastOccurance) {
					stmt.children.findFirst[ trimmableNodePrefix.apply(it) ]
				} else {
					stmt.children.findLast[ trimmableNodePrefix.apply(it) ]
				}
			child?.trim(lastOccurance, trimmer);
		}

		return stmt;
	}
	
	def IGeneratorNode noNewline(IGeneratorNode stmt) {
		if(stmt instanceof CompositeGeneratorNode) {
			val newChildren = stmt.children
				.toList
				.dropWhile[it instanceof NewLineNode || (it instanceof TextNode && (it as TextNode).text == "")]
				.toList
				.reverse
				.dropWhile[it instanceof NewLineNode || (it instanceof TextNode && (it as TextNode).text == "")]
				.toList
				.reverse
				.map[ it.noNewline ]
			
			stmt.children.clear();
			stmt.children.addAll(newChildren);
		}
		
		return stmt
	}
	
	def IGeneratorNode noTerminator(IGeneratorNode stmt) {
		trim(stmt, true, [x|x.trimTerminator]).noNewline;
	}

	def CharSequence trimTerminator(CharSequence stmt) {
		if(stmt === null) return null;

		var result = stmt.toString.trim;
		if (result.endsWith(';')) {
			result = result.substring(0, result.length - 1);
		}
		return result;
	}

	protected def trimBraces(CharSequence code) {
		var result = code.toString.trim();
		if (result.startsWith('{')) {
			result = result.substring(1);
		}
		result = result.replaceAll("\\}$", "");
		return result;
	}

	def IGeneratorNode noBraces(IGeneratorNode stmt) {
		trim(stmt, false, [x|trimBraces(x)]);
		trim(stmt, true, [x|trimBraces(x)]);
	}
	
	def getAllTimeEvents(CompilationContext context) {
		return context.allEventHandlers.filter[x|x.event instanceof TimeIntervalEvent]
	}
	
	def boolean containsCodeRelevantContent(Program it) {
		!eventHandlers.empty || !functionDefinitions.empty || !types.empty || !globalVariables.empty
	}

}
