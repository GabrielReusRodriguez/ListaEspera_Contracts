/* eslint-disable no-undef */
// Right click on the script name and hit "Run" to execute
const { expect } = require("chai");
const { ethers } = require("hardhat");

async function expectRevert(promise, messageFragment) {
  try {
    await promise;
    expect.fail("Expected transaction to revert");
  } catch (error) {
    if (error.message === "Expected transaction to revert") throw error;
    expect(error.message).to.include(messageFragment);
  }
}

describe("ListaEsperaStorageCentros", function () {
  let owner;
  let other;
  let centros;

  beforeEach(async function () {
    [owner, other] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory("ListaEsperaStorageCentros");
    centros = await Factory.deploy(owner.address);
    await centros.deployed();
  });

  it("despliega con lista de centros vacia", async function () {
    console.log("ListaEsperaStorageCentros deployed at:" + centros.address);
    const lista = await centros.getCentros();
    expect(lista.length).to.equal(0);
  });

  it("crea un centro y lo consulta como activo", async function () {
    const tx = await centros.nuevoCentro(other.address, "Hospital Norte");
    await tx.wait();

    const lista = await centros.getCentros();
    expect(lista.length).to.equal(1);
    expect(lista[0].direccion).to.equal(other.address);
    expect(lista[0].nombre).to.equal("Hospital Norte");
    expect(lista[0].activo).to.equal(true);

    expect(await centros.existeCentro(other.address)).to.equal(true);
    expect(await centros.esCentroActivo(other.address)).to.equal(true);
  });

  it("rechaza centro con address zero, nombre vacio o duplicado", async function () {
    await expectRevert(
      centros.nuevoCentro(ethers.constants.AddressZero, "X"),
      "La nueva direccion NO ha de estar en blanco"
    );
    await expectRevert(
      centros.nuevoCentro(other.address, ""),
      "Has de informar el nombre edel centro"
    );

    await (await centros.nuevoCentro(other.address, "Hospital Norte")).wait();
    await expectRevert(
      centros.nuevoCentro(other.address, "Hospital Norte 2"),
      "EL centro que intentas agregar ya esta en la lista"
    );
  });

  it("solo el owner puede crear centros o cambiar el estado", async function () {
    await expectRevert(
      centros.connect(other).nuevoCentro(other.address, "Hack"),
      "Solo el owner puede ejecutar la funcionalidad"
    );
    await expectRevert(
      centros.connect(other).disable(),
      "Solo el owner puede ejecutar la funcionalidad"
    );
  });

  it("desactiva y reactiva el contrato", async function () {
    await (await centros.disable()).wait();
    await expectRevert(
      centros.nuevoCentro(other.address, "Hospital Norte"),
      "El contrato no esta activo"
    );

    await (await centros.enable()).wait();
    await (await centros.nuevoCentro(other.address, "Hospital Norte")).wait();
    expect(await centros.existeCentro(other.address)).to.equal(true);
  });

  it("existeCentro y esCentroActivo devuelven false si no existe", async function () {
    expect(await centros.existeCentro(other.address)).to.equal(false);
    expect(await centros.esCentroActivo(other.address)).to.equal(false);
  });

  it("rechaza esCentroActivo con address zero", async function () {
    await expectRevert(
      centros.esCentroActivo(ethers.constants.AddressZero),
      "La direccion enviada es vacia"
    );
  });
});
