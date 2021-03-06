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

/*
 * generated by Xtext 2.10.0
 */
package org.eclipse.mita.platform.ui.labeling

import com.google.inject.Inject
import java.net.URL
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.edit.ui.provider.AdapterFactoryLabelProvider
import org.eclipse.jface.resource.ImageDescriptor
import org.eclipse.jface.viewers.StyledString
import org.eclipse.mita.base.types.EnumerationType
import org.eclipse.mita.base.types.Enumerator
import org.eclipse.mita.base.types.Event
import org.eclipse.mita.base.types.ExceptionTypeDeclaration
import org.eclipse.mita.base.types.SystemResourceEvent
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.platform.Bus
import org.eclipse.mita.platform.ConfigurationItem
import org.eclipse.mita.platform.Connectivity
import org.eclipse.mita.platform.Modality
import org.eclipse.mita.platform.Sensor
import org.eclipse.mita.platform.Signal
import org.eclipse.mita.platform.SystemResourceAlias
import org.eclipse.xtext.ui.label.DefaultEObjectLabelProvider

/**
 * Provides labels for EObjects.
 * 
 * See https://www.eclipse.org/Xtext/documentation/304_ide_concepts.html#label-provider
 */
class PlatformDSLLabelProvider extends DefaultEObjectLabelProvider {

	@Inject
	new(AdapterFactoryLabelProvider delegate) {
		super(delegate);
	}

	// TODO define images for vci, modiality, bus, exception, signal
	def dispatch Object image(EObject ele) {
		return super.image(ele);
	}

	def dispatch image(Enumerator element) {
		loadImage('enumerator.png')
	}

	def dispatch image(EnumerationType element) {
		loadImage('enumerator.png')
	}

	def dispatch image(Sensor element) {
		loadImage('sensor.png')
	}

	def dispatch image(Connectivity element) {
		loadImage('connectivity.png')
	}

	def dispatch image(Event it) {
		loadImage("event.png")
	}

	def dispatch image(ExceptionTypeDeclaration ele) {
		loadImage('variable.png') // TODO define png for exception?
	}

	def dispatch Object image(SystemResourceAlias it) {
		image(delegate)
	}

	def text(ConfigurationItem ele) {
		'''«IF ele.required»required«ENDIF» configuration «ele.name» : «ele.type»'''
	}

	def text(Sensor ele) {
		'''sensor «ele.name»'''
	}

	def text(SystemResourceAlias ele) {
		'''alias «ele.label» «ele.name» : «ele.delegate?.name»'''
	}

	protected dispatch def String getLabel(SystemResourceAlias alias) {
		return 'sensor';
	}

	protected dispatch def String getLabel(EObject object) {
		return object.eClass.name;
	}

	def text(SystemResourceEvent ele) {
		'''event «ele.name»'''
	}

	def text(Modality ele) {
		val type = BaseUtils.getType(ele);
		'''modality «ele.name» : «type»'''
	}

	def text(Connectivity it) {
		'''connectivity «name»'''
	}

	def text(Bus it) {
		'''bus «name»'''
	}

	def text(ExceptionTypeDeclaration it) {
		'''exception «name»'''
	}

	def text(EnumerationType it) {
		'''enum «name»'''
	}

	def text(Signal it) {
		'''signal «name»'''
	}

	override protected convertToString(Object text) {
		if (text instanceof CharSequence) {
			// enables us to use Xtend templates
			return text.toString();
		} else {
			return super.convertToString(text);
		}
	}

	override protected StyledString convertToStyledString(Object text) {
		if (text instanceof CharSequence) {
			return new StyledString(text.toString);
		}
		return super.convertToStyledString(text)
	}

	private def loadImage(String imageName) {
		val bundleIconUrl = 'platform:/plugin/org.eclipse.mita.program.ui/icons/';
		return ImageDescriptor.createFromURL(new URL(bundleIconUrl + imageName));
	}

}
