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

package org.eclipse.mita.library.extension;

public class Version implements Comparable<Version> {

	private int major;
	private int minor;
	private int micro;

	public static final Version NULL_VERSION = new Version(0, 0, 0);

	public Version(int major, int minor, int micro) {
		this.major = major;
		this.minor = minor;
		this.micro = micro;
	}

	public int getMajor() {
		return major;
	}

	public int getMinor() {
		return minor;
	}

	public int getMicro() {
		return micro;
	}

	@Override
	public int compareTo(Version other) {
		if (this.major > other.getMajor()) {
			return 1;
		}
		if (this.major == other.getMajor()) {

			if (this.minor > other.getMinor()) {
				return 1;
			}
			if (this.minor == other.getMinor()) {

				if (this.micro > other.getMicro()) {
					return 1;
				}

				if (this.micro == other.getMicro()) {
					return 0;
				}
			}
		}
		return -1;
	}

	@Override
	public int hashCode() {
		final int prime = 31;
		int result = 1;
		result = prime * result + major;
		result = prime * result + micro;
		result = prime * result + minor;
		return result;
	}

	@Override
	public boolean equals(Object obj) {
		if (this == obj)
			return true;
		if (obj == null)
			return false;
		if (getClass() != obj.getClass())
			return false;
		Version other = (Version) obj;
		if (major != other.major)
			return false;
		if (micro != other.micro)
			return false;
		if (minor != other.minor)
			return false;
		return true;
	}
	
	@Override
	public String toString() {
		return "Version " + this.major + "." +this.minor + "." + this.micro;
	}
	
	public String toVersionNumberString() {
		return this.major + "." +this.minor + "." + this.getMicro();
	}

	public static Version fromString(String version) {
		String[] split = version.split("\\.");
		return new Version(Integer.parseInt(split[0]), Integer.parseInt(split[1]), Integer.parseInt(split[2]));
	}

}
