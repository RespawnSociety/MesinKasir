<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
  public function up(): void
  {
    Schema::create('store_settings', function (Blueprint $table) {
      $table->id();

      $table->string('store_name');
      $table->text('store_address')->nullable();
      
      $table->decimal('tax_percent', 5, 2)->default(0);

      $table->timestamps();
    });
  }

  public function down(): void
  {
    Schema::dropIfExists('store_settings');
  }
};
