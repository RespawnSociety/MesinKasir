<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Factories\HasFactory;

use Illuminate\Support\Str;

class Transaction extends Model
{
    use HasFactory;

    protected $table = 'transactions';

    protected $fillable = [
        'group_id',
        'cashier_id',
        'items',
        'pay_method',
        'total_amount',
        'paid_amount',
        'change_amount',
        'paid_at',
    ];

    protected $casts = [
        'items' => 'array',
        'pay_method' => 'integer',
        'paid_at' => 'datetime',
        'total_amount' => 'integer',
        'paid_amount' => 'integer',
        'change_amount' => 'integer',
    ];

    public function cashier(): BelongsTo
    {
        return $this->belongsTo(User::class, 'cashier_id');
    }

    protected static function booted(): void
    {
        static::creating(function ($model) {
            if (empty($model->group_id)) {
                $model->group_id = (string) Str::ulid();
            }
        });
    }
}
